import os

# For debug
# log.info("Environment vars are: " + os.environ)

server.wait_for_unit('oar-server.service')
# Submit job with script under user1
frontend.succeed('su - user1 -c "oarsub -l nodes=2 \"hostname\""')

# Wait output job file
frontend.wait_for_file('/users/user1/OAR.1.stdout')

# Check job's final state
frontend.succeed("oarstat -j 1 -s | grep Terminated")

frontend.succeed('su - user1 -c "oarsub -l nodes=2,walltime=1 \"sleep 60\""')
frontend.succeed('su - user1 -c "oarsub -l nodes=1,walltime=3 \"sleep 180\""')
frontend.succeed('su - user1 -c "oarsub -l nodes=1,walltime=2 \"sleep 120\""')

server.succeed('curl http://frontend:8080/drawgantt/')

server.wait_for_unit('k3s.service')
server.wait_until_succeeds('k3s kubectl get nodes | grep Ready', timeout=10)
# This can take some time depending on your network connection
server.wait_until_succeeds('k3s kubectl get pods -A | grep Running', timeout=90)

server.succeed('k3s kubectl apply -f /etc/demo/pod-sleep-100.yml')
server.wait_until_succeeds('k3s kubectl get pods | grep Running', timeout=60)
