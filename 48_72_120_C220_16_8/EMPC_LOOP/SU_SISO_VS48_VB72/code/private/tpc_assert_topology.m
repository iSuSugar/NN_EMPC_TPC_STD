function tpc_assert_topology(sourceFile,candidateFile)
% MATLAB原生检查SLX中的功率连接节点；无需指定个人电脑上的Python。
a=electricalNodes(sourceFile);b=electricalNodes(candidateFile);
assert(isequal(a,b),'Electrical topology differs between local template and candidate.');
fprintf('ELECTRICAL_TOPOLOGY_IDENTICAL nodes=%d\n',numel(a));
end
function nodes=electricalNodes(file)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
unzip(file,folder);doc=xmlread(fullfile(folder,'simulink','systems','system_root.xml'));
root=doc.getDocumentElement;children=root.getChildNodes;
blocks=containers.Map('KeyType','char','ValueType','char');
for k=0:children.getLength-1
 n=children.item(k);
 if strcmp(char(n.getNodeName),'Block'),blocks(char(n.getAttribute('SID')))=char(n.getAttribute('Name'));end
end
nodes={};
for k=0:children.getLength-1
 n=children.item(k);if ~strcmp(char(n.getNodeName),'Line'),continue;end
 props=n.getElementsByTagName('P');ports={};
 for j=0:props.getLength-1
  p=props.item(j);key=char(p.getAttribute('Name'));value=char(p.getTextContent);
  if any(strcmp(key,{'Src','Dst'}))&&(contains(value,'#lconn:')||contains(value,'#rconn:'))
   parts=strsplit(value,'#');ports{end+1}=[blocks(parts{1}) '#' parts{2}]; %#ok<AGROW>
  end
 end
 if ~isempty(ports),nodes{end+1}=strjoin(sort(unique(ports)),'|');end %#ok<AGROW>
end
nodes=sort(nodes);
end
