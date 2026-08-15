[rbe_master]
${workers[0].name} ansible_host=${workers[0].static_ip} ansible_user=${ssh_user} ansible_password=${ssh_password} ansible_become_password=${ssh_password}

[rbe_workers]
%{ for w in workers ~}
%{ if w.name != workers[0].name ~}
${w.name} ansible_host=${w.static_ip} ansible_user=${ssh_user} ansible_password=${ssh_password} ansible_become_password=${ssh_password}
%{ endif ~}
%{ endfor ~}
