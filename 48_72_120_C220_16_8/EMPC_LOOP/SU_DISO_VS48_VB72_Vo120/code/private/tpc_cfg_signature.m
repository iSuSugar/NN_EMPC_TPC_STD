function s=tpc_cfg_signature(cfg)
for n={'codeDir','caseDir','codeRel','caseRel','feedbackTiming'},if isfield(cfg,n{1}),cfg=rmfield(cfg,n{1});end;end
% 模板按本工程内副本的内容标识，搬目录不应导致控制器被误判为失效。
if isfield(cfg,'source')
 [~,name,extension]=fileparts(cfg.source);
 local=fullfile(tpc_project_root(),cfg.caseRel,'circuit','template',[name extension]);
 assert(isfile(local),'Local circuit template missing: %s',local);
 fid=fopen(local,'rb');bytes=fread(fid,inf,'*uint8');fclose(fid);
 md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
 cfg.source=['local-template-sha256:' lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]))];
end
s=tpc_fingerprint(orderfields(cfg));
end
