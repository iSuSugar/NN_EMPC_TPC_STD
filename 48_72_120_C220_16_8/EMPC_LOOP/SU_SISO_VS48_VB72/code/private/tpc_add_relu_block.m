function tpc_add_relu_block(mdl,name,N)
% Portable ReLU inference using standard Simulink blocks; all weights embedded.
path=[mdl '/' name];add_block('built-in/Subsystem',path,'Position',[2050 300 2220 420]);
add_block('simulink/Ports & Subsystems/In1',[path '/Input'],'Position',[25 85 55 105]);
add_block('simulink/Math Operations/Gain',[path '/InputScale'],'Gain',mat2str(diag(N.inputGain),17),'Multiplication','Matrix(K*u)','Position',[90 75 160 115]);
add_block('simulink/Math Operations/Bias',[path '/InputShift'],'Bias',mat2str(N.inputShift,17),'Position',[195 75 265 115]);
chain={'Input','InputScale','InputShift'};
if isfield(N,'rawInputTransform')&&strcmp(N.rawInputTransform,'reference_current')
 add_block('simulink/Signal Routing/Demux',[path '/PhysicalInputs'],'Outputs','4','Position',[70 200 80 400]);add_line(path,'Input/1','PhysicalInputs/1');
 add_block('simulink/Discontinuities/Saturation',[path '/VoltageGuard'],'LowerLimit','1e-6','UpperLimit','inf','Position',[110 240 170 270]);add_line(path,'PhysicalInputs/2','VoltageGuard/1');
 add_block('simulink/Math Operations/Product',[path '/ReferenceCurrent'],'Inputs','**/','Position',[210 260 260 330]);add_line(path,'PhysicalInputs/3','ReferenceCurrent/1');add_line(path,'PhysicalInputs/4','ReferenceCurrent/2');add_line(path,'VoltageGuard/1','ReferenceCurrent/3');
 add_block('simulink/Signal Routing/Mux',[path '/OriginalFeatures'],'Inputs','4','Position',[300 220 310 400]);add_line(path,'PhysicalInputs/1','OriginalFeatures/1');add_line(path,'PhysicalInputs/2','OriginalFeatures/2');add_line(path,'ReferenceCurrent/1','OriginalFeatures/3');add_line(path,'PhysicalInputs/4','OriginalFeatures/4');chain{1}='OriginalFeatures';
end
weights={N.W1,N.W2};biases={N.b1,N.b2};if isfield(N,'W3'),weights{3}=N.W3;biases{3}=N.b3;end
for k=1:numel(weights)
 nameW=sprintf('Layer%d_Weights',k);nameB=sprintf('Layer%d_Bias',k);x=300+300*(k-1);
 add_block('simulink/Math Operations/Gain',[path '/' nameW],'Gain',mat2str(weights{k},17),'Multiplication','Matrix(K*u)','Position',[x 75 x+70 115]);
 add_block('simulink/Math Operations/Bias',[path '/' nameB],'Bias',mat2str(biases{k},17),'Position',[x+100 75 x+170 115]);chain=[chain,{nameW,nameB}]; %#ok<AGROW>
 if k<numel(weights),relu=sprintf('Layer%d_ReLU',k);add_block('simulink/Discontinuities/Saturation',[path '/' relu],'LowerLimit','0','UpperLimit','inf','Position',[x+200 75 x+270 115]);chain{end+1}=relu;end %#ok<AGROW>
end
add_block('simulink/Ports & Subsystems/Out1',[path '/Output'],'Position',[x+230 85 x+260 105]);chain{end+1}='Output';for k=1:numel(chain)-1,add_line(path,[chain{k} '/1'],[chain{k+1} '/1']);end
set_param(path,'UserData',struct('activation','ReLU','externalFeatures',{{'iL','Vo','instantaneous load current','Vref'}},'independentDutyOutputs',size(weights{end},1)),'UserDataPersistent','on');
end
