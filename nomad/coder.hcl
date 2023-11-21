job "coder" {
  datacenters = ["*"]
  
  group "coder"{
    count = 1
    network {
      mode = "host"
      port "coder" {
        to = 8080
      }
    }

    task "coder" {
        driver = "docker"
        meta {
          service = "coder"
        }
        config {
          image = "codercom/code-server:latest"
          ports = ["coder"]
          args = ["--auth","none"]
          volumes = [
            # Use absolute paths to mount arbitrary paths on the host
            "local/repo:/home/coder/project",
          ]
        }
        artifact {
          source      = "https://github.com/BLINKBYTE/nomad/archive/refs/heads/main.zip"
          destination = "local/repo"
        }
    } 
  }
}