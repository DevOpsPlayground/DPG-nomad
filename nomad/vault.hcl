job "vault" {
  datacenters = ["*"]
  
  group "vault"{
    constraint {
      operator  = "distinct_hosts"
      value     = "true"
    }
    count = 2
    network {
      port "vault_api" {
        static = 8200
        to=  8200
      }
      port "vault_cluster" {}
    }

    task "vault" {
      driver = "exec"
      meta {
        service = "vault"
      }
      config {
        command = "local/vault"
        args    = ["server", "-config=local/config.hcl"]
      }
      artifact {
        source      = "https://releases.hashicorp.com/vault/1.14.0/vault_1.14.0_linux_amd64.zip"
        destination = "local"
      }
      template {
          destination = "local/config.hcl"
          data = <<EOH
api_addr = "https://{{env  "attr.unique.platform.aws.public-ipv4"}}:{{env "NOMAD_PORT_vault_api"}}"
cluster_addr = "https://{{env "attr.unique.platform.aws.public-ipv4"}}:{{env "NOMAD_PORT_vault_cluster"}}"
ui = true
storage "raft" {
  path = "local"
  node_id = "{{ env "node.unique.id" }}"
}

listener "tcp" {
  address = "0.0.0.0:{{env  "NOMAD_HOST_PORT_vault_api"}}"
  tls_disable = true
}
            EOH
        }
    } 
  }
}