function [ output_args ] = make_template( hues, sats, vals )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

h = (hues(1):hues(2))./180;
s = (sats(1):sats(2))./256;
v = (vals(1):vals(2))./256;
npoints = length(h)*length(s)*length(v);
cmap = zeros(length(h)*length(s),length(v),3);
for a = 1:length(h)
    for b = 1:length(s)
        currow = b+(a-1)*length(s);
        for c = 1:length(v)
            cmap(currow,c,:) = [h(a) s(b) v(c)];
        end % luminance loop
    end % saturation loop
end % hue loop
cmap = hsv2rgb(cmap);
output_args = imshow(cmap);
end

