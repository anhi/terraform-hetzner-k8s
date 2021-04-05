variable "hcloud_token" {
  type = string
}

variable "ssh_key_name" {
  description = "If not an empty string, terraform will upload your ssh key to the hetzner cloud with that name. See also ssh_public_key_file"
  type = string
  default = ""
}

variable "ssh_public_key_file" {
  description = "The file to read the ssh public key from. Will only be used if ssh_key_name is not empty"
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_file" {
  description = "The file to read the ssh private key from when connecting to the new server for provisioning."
  type = string
  default = "~/.ssh/id_rsa"
}

variable "ssh_agent" {
  description = "Set this to true for password protected private keys; Setthing ssh_agent to true will ignore the ssh_private_key_file setting"
  type = bool
  default = false
}

variable "worker_cnt" {
  type = number
}

variable "worker_server_type" {
  type = list(string)
  default = ["cx21"]
}

variable "worker_additional_setup_script" {
  description = "Optional: Path to a shell script that is run on each worker node for additional setup instructions"
  type = string
  default = null
}

variable "kubeconfig_path" {
  description = "The path to the kubeconfig file for the newly created cluster"
  type = string
}
