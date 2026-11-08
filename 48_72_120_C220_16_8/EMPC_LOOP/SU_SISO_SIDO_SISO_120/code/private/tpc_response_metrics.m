function m=tpc_response_metrics(t,a,Vref,events)
y=a(:,2);i=a(:,1);v=t>=max(.01,t(end)-.001);m=struct('duration',t(end),'finalMeanVoltage',mean(y(v)),'finalRelativeError',abs(mean(y(v))/Vref-1),'peakCurrentIncludingStartup',max(i),'peakCurrentAfter10ms',max(i(t>=.01)),'minimumVoltage',min(y),'maximumVoltage',max(y),'rawDutyMin',min(a(:,4:end),[],1),'rawDutyMax',max(a(:,4:end),[],1));
bin=floor((t+1e-12)*1e5);[~,~,g]=unique(bin);tc=accumarray(g,t)./accumarray(g,1);yc=accumarray(g,y)./accumarray(g,1);E=struct('time',{},'preMean',{},'postMean',{},'peakDepartureV',{},'settlingToPostUs',{},'toleranceV',{});
for j=1:numel(events)
 te=events(j);stop=t(end);if j<numel(events),stop=events(j+1);end;stop=min(stop-.0005,te+.003);
 pre=tc>=te-.001&tc<te;post=tc>=stop-.0005&tc<=stop;w=find(tc>=te&tc<=stop);pm=mean(yc(pre));qm=mean(yc(post));tol=max(.01,.02*abs(qm-pm));bad=w(abs(yc(w)-qm)>tol);recover=0;
 if ~isempty(bad),recover=NaN;if bad(end)<w(end)-1,recover=(tc(bad(end)+1)-te)*1e6;end;end
 E(end+1)=struct('time',te,'preMean',pm,'postMean',qm,'peakDepartureV',max(abs(yc(w)-pm)),'settlingToPostUs',recover,'toleranceV',tol); %#ok<AGROW>
end
m.minimumCurrent=min(i);m.peakAbsoluteCurrentIncludingStartup=max(abs(i));m.peakAbsoluteCurrentAfter10ms=max(abs(i(t>=.01)));ic=accumarray(g,i)./accumarray(g,1);
edges=[0;events(:);t(end)];plateaus=struct('timeWindow',{},'meanVoltage',{},'relativeError',{},'meanLoadCurrent',{},'meanOutputPower',{},'meanDutyCommand',{},'minimumDutyCommand',{},'maximumDutyCommand',{},'cycleMeanCurrentPeakToPeak',{},'meanInductorCurrent',{},'rmsInductorCurrent',{},'minimumInductorCurrent',{},'maximumInductorCurrent',{});
for k=1:numel(edges)-1
 stop=edges(k+1);start=max(edges(k)+.001,stop-.001);w=t>=start&t<stop;cw=tc>=start&tc<stop;vm=mean(y(w));plateaus(k)=struct('timeWindow',[start stop],'meanVoltage',vm,'relativeError',abs(vm/Vref-1),'meanLoadCurrent',mean(a(w,3)),'meanOutputPower',mean(a(w,2).*a(w,3)),'meanDutyCommand',mean(a(w,4:end),1),'minimumDutyCommand',min(a(w,4:end),[],1),'maximumDutyCommand',max(a(w,4:end),[],1),'cycleMeanCurrentPeakToPeak',max(ic(cw))-min(ic(cw)),'meanInductorCurrent',mean(i(w)),'rmsInductorCurrent',sqrt(mean(i(w).^2)),'minimumInductorCurrent',min(i(w)),'maximumInductorCurrent',max(i(w)));
end
m.events=E;m.plateaus=plateaus;m.allPlateausRegulated=all([plateaus.relativeError]<.01);m.voltageRegulated=m.finalRelativeError<.01;m.currentWithin20AIncludingStartup=m.peakAbsoluteCurrentIncludingStartup<=20;m.note='Recovery is computed from PWM-cycle means and the declared band; paper does not define the same numerical band. Cold-start current is reported separately. Final voltage alone does not imply all load/mode plateaus pass.';
end
