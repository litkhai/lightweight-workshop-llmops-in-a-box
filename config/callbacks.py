"""
Language routing callback for the LLMOps-in-a-Box lightweight workshop.

Routing decisions
-----------------
- All requests with model="auto" or model="" are intercepted.
- The dominant Unicode script of the last user message determines the route:

    Hangul (Korean)     → claude-sonnet  (only when ANTHROPIC_API_KEY is set)
    CJK / kana          → local          (Ollama — free, CPU)
    Latin (English, …)  → local          (Ollama — free, CPU)

  If ANTHROPIC_API_KEY is not set, all scripts route to local.

Observability
-------------
- Completion calls are logged to Langfuse via the SDK (not the built-in
  success_callback, which would also log management API noise).
- Each trace gets a `routing` child span recording the language detection
  decision and the chosen model.
"""

import os
import litellm
from langfuse import Langfuse

# ── model aliases ─────────────────────────────────────────────────────────────
_LOCAL_MODEL = "local"
_CLOUD_MODEL = "claude-sonnet"
_HAS_CLOUD   = bool(os.environ.get("ANTHROPIC_API_KEY"))

_ROUTABLE_ALIASES = {"auto", ""}
_SCRIPT_THRESHOLD = 0.15

_langfuse = Langfuse()  # reads LANGFUSE_* env vars


# ── language heuristic ────────────────────────────────────────────────────────

def _dominant_script(text: str) -> str:
    if not text:
        return "latin"
    total = len(text)
    hangul = sum(
        1 for c in text
        if 0xAC00 <= ord(c) <= 0xD7A3
        or 0x1100 <= ord(c) <= 0x11FF
        or 0x3130 <= ord(c) <= 0x318F
    )
    if hangul / total > _SCRIPT_THRESHOLD:
        return "hangul"
    cjk = sum(
        1 for c in text
        if 0x4E00 <= ord(c) <= 0x9FFF
        or 0x3400 <= ord(c) <= 0x4DBF
        or 0x3040 <= ord(c) <= 0x30FF
    )
    if cjk / total > _SCRIPT_THRESHOLD:
        return "cjk"
    return "latin"


# ── Langfuse helpers ──────────────────────────────────────────────────────────

def _span(trace_id: str, name: str, input_: dict, output: dict) -> None:
    try:
        s = _langfuse.span(trace_id=trace_id, name=name, input=input_, output=output)
        s.end()
    except Exception:
        pass


def _extract_output(response_obj) -> str:
    try:
        return response_obj.choices[0].message.content or ""
    except (AttributeError, IndexError):
        return str(response_obj)


# ── callback ──────────────────────────────────────────────────────────────────

class LanguageRouter(litellm.CustomLogger):

    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if call_type not in ("completion", "acompletion"):
            return data
        if data.get("model", "") not in _ROUTABLE_ALIASES:
            return data

        messages = data.get("messages") or []
        last_user = next(
            (m.get("content", "") for m in reversed(messages) if m.get("role") == "user"),
            "",
        )
        call_id = str(data.get("litellm_call_id") or id(data))

        data.setdefault("metadata", {})
        trace_id = data["metadata"].get("trace_id") or call_id
        data["metadata"]["trace_id"] = trace_id

        script = _dominant_script(last_user)
        if script == "hangul" and _HAS_CLOUD:
            routed = _CLOUD_MODEL
        else:
            routed = _LOCAL_MODEL

        data["model"]                        = routed
        data["metadata"]["detected_script"]  = script
        data["metadata"]["routed_model"]     = routed
        data["metadata"]["trace_name"]       = f"chat/{script}"
        data["metadata"]["generation_name"]  = f"{routed}/response"
        data["metadata"]["tags"]             = [
            f"script:{script}",
            f"routed:{routed}",
            "cloud" if routed == _CLOUD_MODEL else "local",
        ]

        _span(trace_id, "routing",
              {"script": script, "message_preview": last_user[:200]},
              {"routed": routed, "cloud_available": _HAS_CLOUD})
        return data

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        # Skip management API calls — they have non-completion call_types or
        # the placeholder "default-message-value" as messages.
        if kwargs.get("call_type") not in ("completion", "acompletion"):
            return
        if kwargs.get("messages") == "default-message-value":
            return

        meta = kwargs.get("litellm_params", {}).get("metadata") or {}
        if not meta.get("routed_model"):
            return

        actual       = getattr(response_obj, "model", None) or kwargs.get("model", "")
        actual_alias = actual.split("/")[-1] if "/" in actual else actual

        tags = list(meta.get("tags") or [])
        tags.append(f"actual:{actual_alias}")
        if actual_alias != meta.get("routed_model"):
            tags.append("fallback:true")

        trace_id = kwargs.get("litellm_call_id") or str(id(kwargs))
        usage    = getattr(response_obj, "usage", None)

        try:
            trace = _langfuse.trace(
                id=trace_id,
                name=meta.get("trace_name", f"chat/{meta.get('detected_script', 'unknown')}"),
                tags=tags,
                metadata={
                    "detected_script": meta.get("detected_script"),
                    "routed_model":    meta.get("routed_model"),
                    "actual_model":    actual_alias,
                },
                input=kwargs.get("messages"),
                output=_extract_output(response_obj),
            )
            gen = trace.generation(
                name=meta.get("generation_name", f"{actual_alias}/response"),
                model=actual,
                input=kwargs.get("messages"),
                output=_extract_output(response_obj),
                usage={
                    "input":  getattr(usage, "prompt_tokens", 0),
                    "output": getattr(usage, "completion_tokens", 0),
                    "total":  getattr(usage, "total_tokens", 0),
                } if usage else None,
                start_time=start_time,
                end_time=end_time,
            )
            gen.end()
            _langfuse.flush()
        except Exception:
            pass

    async def async_post_call_failure_hook(self, data, user_api_key_dict, original_exception):
        if data.get("messages") == "default-message-value":
            return
        meta = data.get("metadata") or {}
        if not meta.get("routed_model"):
            return
        trace_id = str(data.get("litellm_call_id") or id(data))
        try:
            _langfuse.trace(
                id=trace_id,
                name=meta.get("trace_name", "chat/error"),
                tags=(meta.get("tags") or []) + ["error:true"],
                metadata={"error": str(original_exception)[:500]},
            )
            _langfuse.flush()
        except Exception:
            pass


language_router = LanguageRouter()
