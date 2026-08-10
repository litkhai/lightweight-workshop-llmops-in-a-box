"""Choose the workshop model once, while keeping a stable ``auto`` alias."""

import os

import litellm


_HAS_ANTHROPIC = bool(os.environ.get("ANTHROPIC_API_KEY", "").strip())
_TARGET_MODEL = "sonnet" if _HAS_ANTHROPIC else "local"


class WorkshopModelRouter(litellm.CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if call_type not in ("completion", "acompletion"):
            return data
        if data.get("model", "auto") != "auto":
            return data

        data["model"] = _TARGET_MODEL
        metadata = data.setdefault("metadata", {})
        metadata["generation_name"] = f"{_TARGET_MODEL}/response"
        metadata["tags"] = ["self-service-workshop", f"backend:{_TARGET_MODEL}"]
        metadata["workshop_user_id"] = os.environ.get("WORKSHOP_USER_ID", "workshop")
        metadata["routed_model"] = _TARGET_MODEL
        return data


model_router = WorkshopModelRouter()
