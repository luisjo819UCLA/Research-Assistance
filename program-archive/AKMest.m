%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab code for estimation of person and establishment effects %
% among job changes sample in Card, Heining, and Kline (2012).   %
% This script is preceded by the SAS program tomatlab.sas		 %
% which extracts the sample of job switchers.					 %
%																 %
% Due to changes in ichol() command, script requires	 		 %
% Matlab 2011a or later.										 %
%																 %
% Script outputs files AKMeffsx.txt and bhatx.txt which are      %
% analyzed in SAS program postAKMr.sas. That program extends     %
% the analysis to the sample of connected stayers as discussed   %
% in the paper's Appendix.										 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


path(path,'~/matlab_bgl/'); %path to the matlabBGL files 
%note: matlab BGL obtained from http://www.mathworks.com/matlabcentral/fileexchange/10922
system('rm AKMest.log')
diary('AKMest.log')
clear

for i=1:4
s=['Loading data for interval ' int2str(i) '...'];
disp(s);
%LOAD DATA    
s=['interval' int2str(i) 'e.txt'];
data=importdata(s);



id=data(:,1);
year=data(:,2);
firmid=data(:,3);
lagfirmid=data(:,4);
y=data(:,5);
birth=data(:,6);
educ=data(:,7);
fsize=round(data(:,8));
clear data


firmid_old=firmid;
id_old=id;


lagfirmid(lagfirmid==-9)=NaN;


%RENAME
disp('Relabeling ids...')
N=length(y);
sel=~isnan(lagfirmid);

%relabel the firms
[firms,m,n]=unique([firmid;lagfirmid(sel)]);

firmid=n(1:N);
lagfirmid(sel)=n(N+1:end);


%relabel the workers
[ids,m,n]=unique(id);
id=n;

%initial descriptive stats
fprintf('\n')
disp('Some descriptive stats:')
s=['# of p-y obs: ' int2str(length(y))];
disp(s);
s=['# of workers: ' int2str(max(id))];
disp(s);
s=['# of firms: ' int2str(max(firmid))];
disp(s);

s=['mean wage: ' num2str(mean(y))];
disp(s)
s=['variance of wage: ' num2str(var(y))];
disp(s)
fprintf('\n')

%FIND CONNECTED SET
disp('Finding connected set...')
A=sparse(lagfirmid(sel),firmid(sel),1); %adjacency matrix
%make it square
[m,n]=size(A);
if m>n
    A=[A,zeros(m,m-n)];
end
if m<n
    A=[A;zeros(n-m,n)];
end
A=max(A,A'); %connections are undirected

[sindex, sz]=components(A); %get connected sets
idx=find(sz==max(sz)); %find largest set
s=['# of firms: ' int2str(length(A))];
disp(s);
s=['# connected sets:' int2str(length(sz))];
disp(s);
s=['Largest connected set contains ' int2str(max(sz)) ' firms'];
disp(s);
fprintf('\n')
clear A lagfirmid
firmlst=find(sindex==idx); %firms in connected set
sel=ismember(firmid,firmlst);

y=y(sel); firmid=firmid(sel); id=id(sel);
year=year(sel); id_old=id_old(sel); firmid_old=firmid_old(sel);
birth=birth(sel); educ=educ(sel); fsize=fsize(sel); N=length(y); 

disp('Relabeling ids again...')
%relabel the firms
[firms,m,n]=unique(firmid);
firmid=n;

%relabel the workers
[ids,m,n]=unique(id);
id=n;

%descriptive stats for connected set
fprintf('\n')
disp('Now restricted to the largest connected set');
s=['# of p-y obs: ' int2str(length(y))];
disp(s);
s=['# of workers: ' int2str(max(id))];
disp(s);
s=['# of firms: ' int2str(max(firmid))];
disp(s);

s=['mean wage: ' num2str(mean(y))];
disp(s)
s=['variance of wage: ' num2str(var(y))];
disp(s)
fprintf('\n')

%ESTIMATE AKM
disp('Building matrices...')
NT=length(y);
N=max(id);
J=max(firmid);

D=sparse(1:NT,id',1);
F=sparse(1:NT,firmid',1);

S=speye(J-1);
S=[S;sparse(-zeros(1,J-1))];  %N+JxN+J-1 restriction matrix 

%Build time trends
yrmin=min(year); yrmax=max(year);
educmin=min(educ); educmax=max(educ);

R=sparse(1:NT,(year-yrmin+1)+(yrmax-yrmin+1)*educ,1); %year effects by education
idx=1+(yrmax-yrmin+1)*educ;
R(:,idx)=[]; %drop first year effect in each education group


E=sparse(1:NT,educ+1,1);
age=year-birth;
age=(age-40)/40; %rescale to avoid big numbers
A=[bsxfun(@times,E,age.^2),bsxfun(@times,E,age.^3)]; %age cubic by education

Z=[R, A];

clear R E A


X=[D,F*S,Z];

disp('Running AKM...')
tic
xx=X'*X;
xy=X'*y;
L=ichol(xx,struct('type','ict','droptol',1e-2,'diagcomp',.1));
b=pcg(xx,xy,1e-10,1000,L,L');
toc
disp('Done')
clear xx xy L

%ANALYZE RESULTS
xb=X*b;
r=y-xb;

disp('Goodness of fit:')
dof=NT-J-N+1-size(Z,2)
RMSE=sqrt(sum(r.^2)/dof)

TSS=sum((y-mean(y)).^2);
R2=1-sum(r.^2)/TSS
adjR2=1-sum(r.^2)/TSS*(NT-1)/dof

ahat=b(1:N);
ghat=b(N+1:N+J-1);
bhat=b(N+J:end);
disp('check for problems with year effects. should report zero')
sum(bhat==0)

pe=D*ahat;
fe=F*S*ghat;
xb=X(:,N+J:end)*bhat;

clear D F X b

disp('Variance-Covariance of worker and firm effs (p-y weighted)');
cov(pe,fe)
disp('Correlation coefficient');
corr(pe,fe)
disp('Means of person/firm effs')
mean([pe,fe])

disp('Full Covariance Matrix of Components')
disp('    y      pe      fe      xb      r')
C=cov([y,pe,fe,xb,r])

disp('Decomposition #1')
disp('var(y) = cov(pe,y) + cov(fe,y) + cov(xb,y) + cov(r,y)');
c11=C(1,1); c21=C(2,1); c31=C(3,1); c41=C(4,1); c51=C(5,1);
s=[num2str(c11) ' = ' num2str(c21) ' + ' num2str(c31) ' + ' num2str(c41) ' + ' num2str(c51)];
disp(s)
fprintf('\n')
disp('explained shares:    pe       fe       xb       r')
s=['explained shares: ' num2str(c21/c11) '  ' num2str(c31/c11) '  ' num2str(c41/c11) '  ' num2str(c51/c11)];
disp(s)

fprintf('\n')
disp('Decomposition #2')
disp('var(y) = var(pe) + var(fe) + var(xb) + 2*cov(pe,fe) + 2*cov(pe,xb) + 2*cov(fe,xb) + var(r)');
c11=C(1,1); c22=C(2,2); c33=C(3,3); c44=C(4,4); c55=C(5,5); 
c23=C(2,3); c24=C(2,4); c34=C(3,4);
s=[num2str(c11) ' = ' num2str(c22) ' + ' num2str(c33) ' + ' num2str(c44) ' + '  num2str(2*c23) ' + ' num2str(2*c24) ' + ' num2str(2*c34) ' + ' num2str(c55)];
disp(s)
fprintf('\n')
disp('explained shares:    pe      fe      xb   cov(pe,fe)   cov(pe,xb)   cov(fe,xb)   r')
s=['explained shares: ' num2str(c22/c11) '  ' num2str(c33/c11) '  ' num2str(c44/c11) '  ' num2str(2*c23/c11) '  ' num2str(2*c24/c11) '  ' num2str(2*c34/c11) '  ' num2str(c55/c11)];
disp(s)
fprintf('\n')


%joint distribution and separability
fedec = ceil(10 * tiedrank(fe) / length(fe));
pedec = ceil(10 * tiedrank(pe) / length(pe));
for j=1:10
    for k=1:10
        p(j,k)=mean((pedec==j)&(fedec==k));
        meanr(j,k)=mean(r.*(pedec==j).*(fedec==k))/p(j,k);
    end
end
disp('Joint distribution of effects (rows are deciles of pe, cols are deciles of fe)')
p
disp('Mean residual by pe/fe decile')
meanr

clear fedec pedec

%match effects
disp('Match Effects Model')
dig=ceil(max(log10(firmid)));
firmiddec=firmid./(10^dig);
matchid=id+firmiddec;
[matchnew,m,n]=unique(matchid);
matchid=n;

M=sparse(1:NT,matchid',1);
X=[M,Z];
xx=X'*X;
xy=X'*y;
L=ichol(xx,struct('type','ict','droptol',1e-2,'diagcomp',.1));
b=pcg(xx,xy,1e-10,1000,L,L');
r_match=y-X*b;
dof_match=NT-size(X,2)
RMSE_match=sqrt(sum(r_match.^2)/dof_match)
R2_match=1-sum(r_match.^2)/TSS
adjR2_match=1-sum(r_match.^2)/TSS*(NT-1)/dof_match
clear Z r_match b


%further decomposition
fprintf('\n')
disp('Further Decompositions:')
disp('Decomposing residual into match and transitory component')

xx=M'*M;
xy=M'*r;
m=M*(xx\xy);
e=r-m;
disp('Full Covariance Matrix of Components')
disp('    y      pe      fe      xb      m      e')
C=cov([y,pe,fe,xb,m,e])

clear M

%even further decomposition
disp('Decomposing transitory component into firm/year and person component')
F2=sparse(1:NT,(year-yrmin+1)*J+firmid,1);
F2=F2(:,any(F2,1));
xx=F2'*F2;
xy=F2'*e;
L=ichol(xx,struct('type','ict','droptol',1e-2));
bf=pcg(xx,xy,1e-10,1000,L,L');
f=F2*bf;
e2=e-f;
disp('Full Covariance Matrix of Components')
disp('    y      pe      fe      xb      m      f      e2')
C=cov([y,pe,fe,xb,m,f,e2])

clear F2 xx xy m f e e2

%SAVE OUTPUT (this will write to the current directory)
disp('Saving main effects')
out=[id_old firmid_old year pe fe xb r y birth educ fsize];
s=['AKMeffs' int2str(i) 'e.txt'];
dlmwrite(s, out, 'delimiter', '\t', 'precision', 16);

%save bhats
disp('Computing/saving bhat crosswalk')
age=year-birth;
groupid=age+educ/10+year*100; %unique combinations of age, education, and year
[idnew,m,n]=unique(groupid);
G=sparse(1:NT,n,1);
xx=G'*G;
xy=G'*educ;
L=ichol(xx,struct('type','ict','droptol',1e-2));
beduc=pcg(xx,xy,1e-10,1000,L,L');
xy=G'*age;
bage=pcg(xx,xy,1e-10,1000,L,L');
xy=G'*year;
byear=pcg(xx,xy,1e-10,1000,L,L');
xy=G'*xb;
bxb=pcg(xx,xy,1e-10,1000,L,L');
out=[round([beduc bage byear]) bxb];
s=['bhat' int2str(i) 'e.txt'];
dlmwrite(s, out, 'delimiter', '\t', 'precision', 16);

clear id_old firmid_old year y pe fe xb r birth educ fsize age S G groupid bf b xx xy beduc bage byear bxb
end
diary off;
