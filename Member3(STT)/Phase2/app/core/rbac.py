from typing import List, Dict

# Define Roles and their Permissions
ROLES: Dict[str, Dict[str, List[str]]] = {
    "Admin": {
        "can": ["*"]
    },
    "Teacher": {
        "can": [
            "s3:read",
            "s3:write",
            "db:read",
            "db:write",
            "kafka:produce",
            "stt:transcribe",
            "stt:read"
        ]
    },
    "Student": {
        "can": [
            "s3:read",
            "db:read",
            "stt:read"
        ]
    }
}

def has_permission(role: str, action: str) -> bool:
    """
    Checks if a user role has permission to perform an action.
    """
    role_config = ROLES.get(role)

    if not role_config:
        return False

    # Check for wildcard permission
    if "*" in role_config["can"]:
        return True

    # Check for specific permission
    return action in role_config["can"]

def enforce_permission(role: str, action: str):
    """
    Enforces permission, throwing an exception if denied.
    """
    if not has_permission(role, action):
        raise PermissionError(f"ACCESS DENIED: Role '{role}' cannot perform '{action}'.")
