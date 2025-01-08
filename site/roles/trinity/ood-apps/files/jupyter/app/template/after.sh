# Wait for the Jupyter Notebook server to start
echo "Waiting for Jupyter Notebook server to open port ${port}..."
if wait_until_port_used "${host}:${port}" 60; then
  echo "Discovered Jupyter Notebook server listening on port ${port}!"
else
  echo "Timed out waiting for Jupyter Notebook server to open port ${port}!" ; exit 1
fi
sleep 2
