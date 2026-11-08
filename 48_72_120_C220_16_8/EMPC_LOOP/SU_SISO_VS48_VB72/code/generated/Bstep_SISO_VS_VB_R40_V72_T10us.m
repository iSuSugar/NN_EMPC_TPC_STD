function [u,region]=Bstep_SISO_VS_VB_R40_V72_T10us(x)
x=x(:);[u,region]=Bstep_SISO_VS_VB_R40_V72_T10us_scaled(x./[18;86.399999999999991]);
end
