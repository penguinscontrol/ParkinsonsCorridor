function [ output_video ] = kin_analysis_fun( kin_str )
%kin_analysis_fun.m Analysis of kinematic variables
%   Detailed explanation goes here


load(kin_str);
nsamp = length(kin.RedX);
lowbound = 100; % x locations less than 100 are discounted because they
                % are very jittery
losttag = 5000; % if the tracking lost the foot
notracktag = 10000; % if we haven't started tracking yet
highbound = losttag; % everything less than this 
                  % represents actual movement coordinates
        
redvalid = kin.RedX > lowbound & kin.RedX < highbound;
bluvalid = kin.BlueX > lowbound & kin.BlueX < highbound;
valid = redvalid & bluvalid;
% find putative liftoffs for red and blue
redlift = false(1,nsamp);
blulift = false(1,nsamp);
reddown = false(1,nsamp);
bludown = false(1,nsamp);

min_step_size = 7;
% minimum number of frames between a liftoff and a touchdown

a = 2;
look_for_down = false;

while a < nsamp
    if look_for_down % look for touchdown
        if redvalid(a) 
            reddown(a) = true;
            look_for_down = false;
        end
    else       % loof for liftoff
        if redvalid(a-1) && kin.RedX(a) == losttag
            redlift(a) = true;
            look_for_down = true;
            a = a+min_step_size-1;
        end
    end
    a = a+1;    
end


a = 2;
look_for_down = false;
while a < nsamp
    if look_for_down % look for touchdown
        if  bluvalid(a)
            bludown(a) = true;
            look_for_down = false;
        end
    else       % loof for liftoff
        if bluvalid(a-1) && kin.BlueX(a) == losttag 
            blulift(a) = true;
            look_for_down = true;
            a = a+min_step_size-1;
        end
    end
    a = a+1;
end
    

%%

t = 0:1/30:nsamp/30;
%% Stepping histogram

trlift = t(redlift); trdown = t(reddown);
% time of red liftoff and touchdown respectively
tblift = t(blulift); tbdown = t(bludown);
% time of blue liftoff and touchdown respectively

rl_isi = diff(trlift);
% inter liftoff intervals
bl_isi = diff(tblift);
% inter touchdown intervals
red_stl = [];
blu_stl = [];
for a = 1:length(trlift)
    wheredown = find(trdown > trlift(a), 1);
    if wheredown
        corresponding_down = trdown(wheredown);
    red_stl = [red_stl (corresponding_down - trlift(a))];
    end
end

for a = 1:length(tblift)
    wheredown = find(tbdown > tblift(a), 1);
    if wheredown
        corresponding_down = tbdown(wheredown);
    blu_stl = [blu_stl (corresponding_down - tblift(a))];
    end
end


figure();
histogram(rl_isi(rl_isi < 2),50,...
    'EdgeColor', 'none', 'FaceColor', [1 0 0], 'FaceAlpha', 0.5);
hold on;
histogram(bl_isi(bl_isi < 2),50,...
    'EdgeColor', 'none', 'FaceColor', [0 0 1], 'FaceAlpha', 0.5);
title('inter-liftoff intervals');
ylabel('count');
xlabel('time (s)');
print('-djpeg', [kin_str 'l_hist']);

figure();
histogram(red_stl(red_stl < 1),50,...
    'EdgeColor', 'none', 'FaceColor', [1 0 0], 'FaceAlpha', 0.5);hold on;
histogram(blu_stl(blu_stl < 1),50,...
    'EdgeColor', 'none', 'FaceColor', [0 0 1], 'FaceAlpha', 0.5);
title('Step lengths');
ylabel('count');
xlabel('time (s)');
print('-djpeg', [kin_str 'l2d_hist'])

fprintf('Done!');

end

