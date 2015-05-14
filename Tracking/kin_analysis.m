%%
clear; clc; close all;

load('20141125_Leon_Tunnel');
vidObj = ...
    VideoReader('E:\Google Drive\ODBS\practice_video\20141119_Leon_Tunnel_1.mpg');
startTime = 22;

vidHeight = vidObj.Height;
vidWidth = vidObj.Width;

nsamp = length(kin.RedX);
t = 0:1/30:nsamp/30;
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

for a = 2:nsamp
    if kin.RedX(a) == losttag && redvalid(a-1) 
        redlift(a) = true;
    end
    
    if redvalid(a) && kin.RedX(a-1) == losttag
        reddown(a) = true;
    end
    
    if kin.BlueX(a) == losttag && bluvalid(a-1) 
        blulift(a) = true;
    end
    
    if bluvalid(a) && kin.BlueX(a-1) == losttag
        bludown(a) = true;
    end
end

%% Stepping histogram

trlift = t(redlift); trdown = t(reddown);
tblift = t(blulift); tbdown = t(bludown);

rl_isi = diff(trlift);
bl_isi = diff(tblift);
    
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
histogram(rl_isi(rl_isi < 2 & rl_isi > 0.15),50,...
    'EdgeColor', 'none', 'FaceColor', [1 0 0], 'FaceAlpha', 0.5);
hold on;
histogram(bl_isi(bl_isi < 2 & bl_isi > 0.15),50,...
    'EdgeColor', 'none', 'FaceColor', [0 0 1], 'FaceAlpha', 0.5);
title('inter-liftoff intervals');
ylabel('count');
xlabel('time (s)');

figure();
histogram(red_stl(red_stl < 1),50,...
    'EdgeColor', 'none', 'FaceColor', [1 0 0], 'FaceAlpha', 0.5);hold on;
histogram(blu_stl(blu_stl < 1),50,...
    'EdgeColor', 'none', 'FaceColor', [0 0 1], 'FaceAlpha', 0.5);
title('Step lengths');
ylabel('count');
xlabel('time (s)');

%%
figure(); currAxes = axes;
set(gcf,'position',[150 150 vidObj.Width vidObj.Height]);
set(gca,'units','pixels');
set(gca,'position',[0 0 vidObj.Width vidObj.Height]);

for a = 1:nsamp
    if vidObj.CurrentTime > startTime;
        clc;
        fprintf('Frame %d of %d\n', a, nsamp);
        vidFrame = readFrame(vidObj);
    
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
        
        vidFrame = insertText(vidFrame, [50 250], sprintf('T = %4.4f', t(a)));
        image(vidFrame);
        pause;
        %writeVideo(writerObj, vidFrame);
    else
        readFrame(vidObj);
    end
end

fprintf('Done!');