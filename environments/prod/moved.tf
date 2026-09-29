# The vm-access tunnel became the admin tunnel (#115): the same tunnel,
# renamed in place. Remove once applied.
moved {
  from = module.access_tunnel
  to   = module.admin_tunnel
}
