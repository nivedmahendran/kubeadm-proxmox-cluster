output "nodes" {
  description = "Cluster node name -> IP mapping"
  value = {
    for name, n in local.nodes : name => n.ip
  }
}

output "control_plane_ip" {
  description = "Control-plane node IP"
  value       = local.nodes["k8s-cp1"].ip
}

output "worker_nodes" {
  description = "Worker node IPs"
  value = [
    local.nodes["k8s-worker1"].ip,
    local.nodes["k8s-worker2"].ip,
  ]
}
