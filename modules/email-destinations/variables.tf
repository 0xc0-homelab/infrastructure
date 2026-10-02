variable "account_id" {
  description = "Cloudflare account the destinations belong to."
  type        = string
}

variable "emails" {
  description = "Mailboxes mail is forwarded to, by a name of the caller's choosing."
  type        = map(string)
  sensitive   = true
}
