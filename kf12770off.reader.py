import sys,os,time
sys.stdout.write('\033[>4;2m'); sys.stdout.flush()
time.sleep(0.5)
data=os.read(0,64)
open('/tmp/kf12770off.raw','wb').write(data)
