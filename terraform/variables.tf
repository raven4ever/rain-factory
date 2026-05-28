variable "atlas_public_key" {
  description = "MongoDB Atlas programmatic API public key. Source via TF_VAR_atlas_public_key env var."
  type        = string
  sensitive   = true
}

variable "atlas_private_key" {
  description = "MongoDB Atlas programmatic API private key. Source via TF_VAR_atlas_private_key env var."
  type        = string
  sensitive   = true
}

variable "user_passwords" {
  description = "Map of database username to password. Used only for SCRAM auth users (Phase 3)."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "federation_settings_id" {
  description = "Atlas Federation Settings ID. Required only if org.yaml federation.enabled = true (Phase 4)."
  type        = string
  default     = null
}
