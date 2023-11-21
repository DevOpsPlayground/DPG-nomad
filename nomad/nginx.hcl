job "nginx" {
  datacenters = ["*"]
  
  group "nginx"{
    count = 1
    network {
      mode = "host"
      port "web" {
        to = 80
      }
    }
    service {
      provider = "nomad"
      port = "web"
      check {
        type     = "http"
        name     = "app_health"
        path     = "/"
        interval = "20s"
        timeout  = "5s"

        check_restart {
          limit = 3
          grace = "90s"
          ignore_warnings = false
        }
      }
    }
    task "nginx" {
        driver = "docker"
        meta {
          service = "nginx"
        }
        config {
          image = "nginx:latest"
          ports = ["web"]
        }
    } 
  }
}