function s=tpc_fingerprint(varargin)
% SHA-256 of explicit inputs, used to prevent stale controller reuse.
md=java.security.MessageDigest.getInstance('SHA-256');
for k=1:nargin,md.update(uint8(unicode2native(jsonencode(varargin{k}),'UTF-8')));end
s=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
