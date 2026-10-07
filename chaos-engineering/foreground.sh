# Waiting for setup to finish
until [ -f /root/.setup-done ]; do sleep 1; done; clear; echo "Setup finished."
