output "account_id" {
  description = "The zone's account: where its destinations must exist (email-destinations)."
  value       = local.account_id
}

output "destinations_used" {
  description = "Names of the destinations this zone's rules and catch-all forward to."
  value       = nonsensitive(toset(concat(values(var.forwards), var.catch_all == null ? [] : [var.catch_all])))
}

output "pending" {
  description = "How many of this zone's forwards wait for their destination's confirmation."
  value       = nonsensitive(length(local.rules)) - length(local.ready)
}
