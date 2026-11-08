function y=tpc_nn_predict(net,x)
if isfield(net,'rawInputTransform')&&strcmp(net.rawInputTransform,'reference_current'),x(3,:)=x(3,:).*x(4,:)./max(x(2,:),1e-6);end
x=net.inputGain.*x+net.inputShift;
h=max(0,net.W1*x+net.b1);
if isfield(net,'W3'),y=net.W3*max(0,net.W2*h+net.b2)+net.b3;else,y=net.W2*h+net.b2;end
end
