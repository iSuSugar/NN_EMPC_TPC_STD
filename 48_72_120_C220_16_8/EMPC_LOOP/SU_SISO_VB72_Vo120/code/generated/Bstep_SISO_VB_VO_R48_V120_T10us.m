function [u,region]=Bstep_SISO_VB_VO_R48_V120_T10us(x)
x=x(:);[u,region]=Bstep_SISO_VB_VO_R48_V120_T10us_scaled(x./[18;144]);
end
