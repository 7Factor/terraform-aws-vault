output "lb_dns" {
  value       = aws_lb.vault_lb.dns_name
  description = "The DNS value of your ELB hosting the vault cluster. Point your FQDN to it."
}
