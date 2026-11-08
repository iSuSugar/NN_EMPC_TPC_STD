function [u,region]=Bstep_SISO_VS_VO_R48_V120_T10us(x)
x=x(:);[u,region]=Bstep_SISO_VS_VO_R48_V120_T10us_scaled(x./[18;144]);
end
