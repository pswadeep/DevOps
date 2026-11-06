import argparse, sys
ap = argparse.ArgumentParser()
ap.add_argument('--weights'); ap.add_argument('--data'); ap.add_argument('--min-map', type=float, default=0.8)
a = ap.parse_args()
from ultralytics import YOLO
m = YOLO(a.weights).val(data=a.data)
map50 = float(m.box.map50)
print('mAP50', map50)
sys.exit(0 if map50 >= a.min_map else 1)
