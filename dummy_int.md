# Create dummy interface
Instructions on how to creat a dummy interface

### Create interface
```bash
sudo modprobe dummy
sudo ip link add eth1 type dummy
sudo ifconfig eth1 up
```

### Add interface to the switch in Mininet 
```python
self.addIntf(spine1,"eth1")
```