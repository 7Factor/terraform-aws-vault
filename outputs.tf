output "lb_dns" {
  value       = aws_lb.vault_internal_lb.dns_name
  description = "The DNS value of your ELB hosting the vault cluster. Point your FQDN to it if you are using a VPN."
}

output "pub_lb_dns" {
  value       = aws_lb.vault_external_lb[*].dns_name
  description = "The DNS value of your external ELB hosting the vault cluster. Point your FQDN to it if you are not using a VPN."
}
