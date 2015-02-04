function [ output_video ] = kin_analysis_fun( kin_str, vid_str, offset, savetofile )
%kin_analysis_fun.m Analysis of kinematic variables
%   Detailed explanation goes here

if savetofile
    output_video = [kin_str '_proc_video.avi'];
    writerObj = VideoWriter(output_video);
    open(writerObj);
end

load(kin_str); 
vidObj = ...
    VideoReader(vid_str);

if nargin < 3
    startTime = 0;
else
    startTime = offset;
end

vidHeight = vidObj.Height;
vidWidth = vidObj.Width;

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
figure(); currAxes = axes;
set(gcf,'position',[150 150 vidObj.Width vidObj.Height]);
set(gca,'units','pixels');
set(gca,'position',[0 0 vidObj.Width vidObj.Height]);

t = zeros(1,nsamp); count = 1;
for a = 1:nsamp
    if vidObj.CurrentTime > startTime;
        clc;
        drawnow;
        fprintf('Frame %d of %d\n', a, nsamp);
        vidFrame = readFrame(vidObj);
        t(count) = vidObj.CurrentTime;
        if redvalid(a)
            vidFrame = insertShape(vidFrame,'circle',...
                [kin.RedX(a) kin.RedY(a) 5],'LineWidth', 5, 'Color', 'red');
        end
    
        if bluvalid(a)
            vidFrame = insertShape(vidFrame,'circle',...
                [kin.BlueX(a) kin.BlueY(a) 5],'LineWidth', 5, 'Color', 'blue');
        end
    
        if redlift(a)
            vidFrame = insertText(vidFrame, [50 50], 'Red liftoff');
        end
    
        if blulift(a)
            vidFrame = insertText(vidFrame, [50 100], 'Blue liftoff');
        end
    
        if reddown(a)
            vidFrame = insertText(vidFrame, [50 150], 'Red down');
        end
    
        if bludown(a)
            vidFrame = insertText(vidFrame, [50 200], 'Blue down');
        end
        
        vidFrame = insertText(vidFrame, [50 250], sprintf('T = %4.4f', t(count)));
        
        if savetofile
            writeVideo(writerObj, vidFrame);
        else
            image(vidFrame);
            pause;
        end
        count = count+1;
    else
        readFrame(vidObj);
    end
end
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

