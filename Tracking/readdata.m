function kinematics = readdata()

fID = fopen('C:\Users\Radu Darie\Documents\GitHub\ParkinsonsCorridor\Tracking\ColorTracker\Release\redXYfile.bin');
A = fread(fID,'int32');
xr = A(1:2:end);
yr = A(2:2:end);
fclose(fID);

fID = fopen('C:\Users\Radu Darie\Documents\GitHub\ParkinsonsCorridor\Tracking\ColorTracker\Release\bluXYfile.bin');
B = fread(fID, 'int32');
xb = B(1:2:end);
yb = B(2:2:end);

fID = fopen('C:\Users\Radu Darie\Documents\GitHub\ParkinsonsCorridor\Tracking\ColorTracker\Release\redANfile.bin');
anr = fread(fID, 'float');

fID = fopen('C:\Users\Radu Darie\Documents\GitHub\ParkinsonsCorridor\Tracking\ColorTracker\Release\bluANfile.bin');
anb = fread(fID, 'float');

fID = fopen('C:\Users\Radu Darie\Documents\GitHub\ParkinsonsCorridor\Tracking\ColorTracker\Release\redARfile.bin');
arr = fread(fID, 'int32');

fID = fopen('C:\Users\Radu Darie\Documents\GitHub\ParkinsonsCorridor\Tracking\ColorTracker\Release\bluANfile.bin');
arb = fread(fID, 'int32');

kinematics = struct('RedX', xr, 'RedY', yr, 'RedArea', arr, 'RedAngle', anr,...
    'BlueX', xb, 'BlueY', yb, 'BlueArea', arb, 'BlueAngle', anb);
end