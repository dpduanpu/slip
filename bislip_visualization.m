% adapted from http://blogs.mathworks.com/graphics/2014/10/21/double_pendulum/
function bislip_visualization(block)

setup(block)


function setup(block)

block.NumInputPorts  = 1;
block.NumOutputPorts = 0;

block.SetPreCompInpPortInfoToDynamic;

block.InputPort(1).Dimensions = 14;
block.InputPort(1).DatatypeID = 0;  % double
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;

block.NumDialogPrms = 1;

block.RegBlockMethod('Start',                @Start);
block.RegBlockMethod('Outputs',              @Output);

block.SetSimViewingDevice(true);


function Start(block)

ud = get_param(block.BlockHandle, 'UserData');
if isempty(ud)
    vis = [];
else
    vis = ud.vis;
end

if isempty(vis) || ~isa(vis, 'BiSLIPGraphics') || ~vis.isAlive()
    vis = BiSLIPGraphics();
else
    vis.clearTrace();
end

ud.vis = vis;
set_param(block.BlockHandle, 'UserData', ud);



function Output(block)

if block.IsMajorTimeStep
    
    ud = get_param(block.BlockHandle, 'UserData');
    vis = ud.vis;
    
    if isempty(vis) || ~isa(vis, 'BiSLIPGraphics') || ~vis.isAlive()
        return;
    end
    
    body = block.InputPort(1).Data(1:2);
    angle = block.InputPort(1).Data(3);
    toeA = block.InputPort(1).Data(7:8);
    toeB = block.InputPort(1).Data(11:12);
    
    vis.setState(body, angle, toeA, toeB);
    vis.setGround(@(x) ground_height_interp(x, block.DialogPrm(1).Data), 100);
end


function y = ground_height_interp(x, ground_data)

y = zeros(size(x));

for i = 1:length(x)
    [~, yi] = polyxpoly([x(i) x(i)], [-1e3 1e3], ground_data(:, 1), ground_data(:, 2));
    if ~isempty(yi)
        y(i) = max(yi);
    else
        y(i) = NaN;
    end
end


