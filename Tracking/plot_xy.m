function plot_xy(k)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
figure();
xr = k.RedX;
xb = k.BlueX;
yr = k.RedY;
yb = k.BlueY;

outfile = 'vis.gif';
plotxr = 0;
plotyr = 0;
plotxb = 0;
plotyb = 0;
for a = 1:5:length(xr)
    if xr(a) < 4000
        plotxr = xr(a);
        plotyr = yr(a);
    end
    if xb(a) < 4000
        plotxb = xb(a);
        plotyb = yb(a);
    end
        plot(plotxr, plotyr,'ro', 'LineWidth', 3);
        hold on;
        plot(plotxb, plotyb,'bo', 'LineWidth', 3);
        hold off;
    set(gcf,'color','w'); % set figure background to white
    axis([min([xr(xr < 4000); xb(xb < 4000)])...
        max([xr(xr < 4000); xb(xb < 4000)])...
        min([yr(yr < 4000); yb(yb < 4000)])...
        max([yr(yr < 4000); yb(yb < 4000)])]);
    drawnow;
    frame = getframe(1);
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    % On the first loop, create the file. In subsequent loops, append.
    if a==1
        imwrite(imind,cm,outfile,'gif','DelayTime',0,'loopcount',inf);
    else
        imwrite(imind,cm,outfile,'gif','DelayTime',0,'writemode','append');
    end

end

