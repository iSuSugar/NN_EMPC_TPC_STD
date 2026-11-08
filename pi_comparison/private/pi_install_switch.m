function pi_install_switch(mdl,old,p,warm,head,events,activeFirst)
parent=get_param(old,'Parent');ph=get_param(old,'PortHandles');
src=sourcePort(get_param(ph.Inport(1),'Line'));line=get_param(ph.Outport(1),'Line');dst=get_param(line,'DstPortHandle');dst=dst(dst>0);pos=get_param(old,'Position');oldName=get_param(old,'Name');delete_line(line);delete_block(old);
name=[parent '/' strrep(oldName,'TPC_NN','PI_Cascade')];add_block('simulink/User-Defined Functions/MATLAB Function',name,'Position',pos);
clock=[name '_Clock'];add_block('simulink/Sources/Digital Clock',clock,'SampleTime',num2str(p.Ts,17),'Position',[pos(1)-150 pos(2)+120 pos(1)-100 pos(2)+150]);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',name);
body=fileread(fullfile(fileparts(fileparts(mfilename('fullpath'))),'pi_controller_template.txt'));
body=strrep(body,'@PARAMETERS@',sprintf('Ts=%s;kpI=%s;kiI=%s;kpV=%s;kiV=%s;dir=%s;ub=%s;lo=%s;hi=%s;ib=%s;imin=%s;imax=%s;warm=%s;',...
 num2str(p.Ts,17),num2str(p.KpI,17),num2str(p.KiI,17),num2str(p.KpV,17),num2str(p.KiV,17),mat2str(p.direction,17),mat2str(p.uBase,17),mat2str(p.uMin,17),mat2str(p.uMax,17),num2str(p.iBase,17),num2str(p.currentMin,17),num2str(p.currentMax,17),num2str(warm,17)));
if activeFirst,active=sprintf('(t<%s||t>=%s)',num2str(warm+events(1),17),num2str(warm+events(2),17));else,active=sprintf('(t>=%s&&t<%s)',num2str(warm+events(1),17),num2str(warm+events(2),17));end
body=strrep(body,'if t<warm',['if t<warm||~' active]);
body=strrep(body,'function u=control(features,t)','function command=control(features,t)');
body=strrep(body,'u=ub;return',sprintf('u=ub;command=u(%d);return',head));
body=regexprep(body,'\s*end\s*$','');
body=[body sprintf('\ncommand=u(%d);\nend\n',head)];
chart.Script=body;np=get_param(name,'PortHandles');cp=get_param(clock,'PortHandles');
connectPort(parent,src,np.Inport(1));connectPort(parent,cp.Outport(1),np.Inport(2));
for d=unique(dst(:))',connectPort(parent,np.Outport(1),d);end
set_param(parent,'AttributesFormatString','Discrete voltage PI -> current PI -> identical duty limits');
end
function connectPort(parent,src,dst)
lh=get_param(dst,'Line');if lh>0
 old=sourcePort(lh);if old==src,return;end
 if old>0,delete_line(parent,old,dst);else,delete_line(lh);end
end
add_line(parent,src,dst,'autorouting','on');
end
function sp=sourcePort(line)
sp=get_param(line,'SrcPortHandle');while sp<0,parent=get_param(line,'LineParent');if isempty(parent)||parent<0,return;end;line=parent;sp=get_param(line,'SrcPortHandle');end
end
