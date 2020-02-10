variable "environment" {
}

provider "digitalocean" {}

resource "digitalocean_droplet" "grundstuecksinformation-srv" {
    name  = "grundstuecksinformation-srv-${var.environment}"
    image = "docker-18-04"
    region = "fra1"
    #size = "s-3vcpu-1gb"
    #size = "s-2vcpu-4gb"
    size = "s-1vcpu-1gb"
    ssh_keys = [25503420,24397269]
	user_data = <<-EOF
    #cloud-config
    users:
      - name: appuser
        shell: /bin/bash
    package_upgrade: false
    runcmd:
      - apt update
      - mkdir --mode=0777 /pgdata
      - mkdir -p /certs/.caddy
      - usermod -aG docker appuser
      - openssl genrsa -out /certs/ca.key 2048
      - openssl req -extensions v3_req -new -x509 -days 365 -key /certs/ca.key -subj '/C=CH/ST=Solothurn/L=Solothurn/O=AGI/OU=SOGIS/CN=grundstuecksinformation.ch' -out /certs/ca.crt
      - openssl req -extensions v3_req -newkey rsa:2048 -nodes -keyout /certs/server.key -subj '/C=CH/ST=Solothurn/L=Solothurn/O=AGI/OU=SOGIS/CN=grundstuecksinformation.ch' -out /certs/server.csr
      - echo "subjectAltName=DNS:grundstuecksinformation.ch\nextendedKeyUsage=serverAuth,clientAuth" > /certs/config.file
      - openssl x509 -req -extfile /certs/config.file -days 365 -in /certs/server.csr -CA /certs/ca.crt -CAkey /certs/ca.key -CAcreateserial -out /certs/server.crt
      - usermod -aG docker appuser      
      - chown -R appuser:appuser /certs
      - su - appuser -c "docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')"
      - su - appuser -c "docker volume create portainer_data" 
      - su - appuser -c "docker run -d -p 9443:9000 -p 8000:8000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock -v /certs:/certs -v portainer_data:/data portainer/portainer --ssl --sslcert /certs/server.crt --sslkey /certs/server.key"
    EOF
    monitoring = true
    backups = false
}

resource "digitalocean_project" "grundstuecksinformation-srv" {
    name        = "GRUNDSTUECKSINFORMATION-SRV-${var.environment}"
    description = "GRUNDSTUECKSINFORMATION-SRV"
    purpose     = "Web Application"
    resources   = [digitalocean_droplet.grundstuecksinformation-srv.urn]
}
