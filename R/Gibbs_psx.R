
gibbs_psx_fun<-function(MCMAX, NZ, NY, N, Y, LY_int, IDY0, IDY, nthin, N.burn, CIR)
{
#### def_rec ###################################################################
IDMU<-rep(1,NY)  # now MU is estimated
IDMUA<-any(as.logical(IDMU))

NM<-0	             #dimension of eta (q_1)
NK<-NM+NZ	       #dimension of latent variables (eta+xi);  number of factors

############################## Automatic done
#Y<-array(0,dim=c(NY,N))			#observed data Y

xi<-array(dim=c(NZ,N))			#independent latent variable xi
eta<-array(dim=c(NM,N))			#dependent latent variable eta
TUE<-Omega<-array(dim=c(NK,N))	#latent variable omega

NMU<-sum(IDMU)			      #number of Mu in measurement equation.
NLY<-sum(IDY)				#number of free lambda need to be estimated in Lambda.

IDMU <- rep(1,NY)  # now MU is estimated
IDMUA<-any(as.logical(IDMU))

#Nrec<-(MCMAX-N.burn)/nthin		#number of samples after burn-in.
Nrec<-MCMAX/nthin #save all then extract

EMU<-array(0,dim=c(Nrec,NMU))		#Store retained trace of MU
ELY<-array(0,dim=c(Nrec,NLY))		#Store retained trace of Lambda
EPSX<-array(0,dim=c(Nrec,NY,NY))	#Store retained trace of PSX
EinvPSX<-array(0,dim=c(Nrec,NY,NY)) #Store retained trace of inv(PSX)
EPHI<-array(0,dim=c(Nrec,(NZ*NZ)))	#Store retained trace of PHI
EXI<-array(0,dim=c(Nrec,NZ,N))	#Store retained trace of xi
Elambda<-array(0,dim=c(Nrec,1))     #Store retained trace of shrinkage paraemter lambda



indmx<-matrix(1:NY^2, nrow=NY, ncol=NY)
temp<-indmx[upper.tri(indmx)]
upperind<-temp[temp>0]

indmx_t<-t(indmx)
temp<-indmx_t[upper.tri(indmx_t)]
lowerind<-temp[temp>0]

tau<-array(0,dim=c(NY,NY))

ind_noi_all<-array(0,dim=c(NY-1,NY))

for(i in 1:NY){

   if(i==1) {ind_noi<-2:NY}
   else if(i==NY) {ind_noi<-1:(NY-1)}
   else ind_noi<-c(1:(i-1),(i+1):NY)

   ind_noi_all[,i]<-ind_noi

} # end of i



chainpsx<-array(0,dim=c(Nrec,NY*(NY+1)/2))
Epostp<-array(0, dim=c(MCMAX-N.burn,1))


### prior ##########################################################
#Prior mean of Lambda, NY*NZ
#PLY_matrix<-matrix(0.0,nrow=NY,ncol=length(mmvar))
#for (i in 1:length(mmvar))
#{
#	PLY_matrix[mmvar_loc[[i]][1],i]<-1.0
#}
#PLY<-PLY_matrix
PLY<-array(0,dim=c(NY,NZ))
PLY[which(IDY0==9)] = 1

#Prior mean of MU, NY*1
PMU<-rep(0.0,NY)

#Inverse prior variance of unknown parameters in factor loading matrix
sigly<-0.25

#Inverse prior variance of unknown parameters in intercept
sigmu<-0.25

rou.scale<- 100

#rho_0, hyperparameters of Wishart distribution
rou.zero<-rou.scale+NZ+1

#Matrix R_0, hyperparameters of Wishart distribution
R.zero<-rou.scale*diag(1,NZ)

#Hyperparameters of Gamma distribution for the shrinkage parameter
a_lambda<-1
b_lambda<-0.0001

#if (category)
#{
#	rou.scale2<-6.0

#	#rho_0,      hyperparameters of Wishart distribution	for PSX
#	rou.zero2<-rou.scale2+NY+1

#	#matrix R_0,      hyperparameters of Wishart distribution for PSX
#	R.zero2<-rou.scale2*diag(1,NY)
#}

###  set init ####################################################################
# Creat the matrix of missing indicators where 1 represents missing
missing_ind = array(0, dim=c(NY, N))
Y_missing = array(0, dim=c(NY,N,MCMAX))

for(i in 1:NY)
   for(j in 1:N)
      if(is.na(Y[i,j])) missing_ind[i,j]<-1



LY<-LY_int
MU<<-rep(1.0,NY)

#initial value of PHI
PHI<<-matrix(0.0,nrow=NZ,ncol=NZ)
diag(PHI[,])<-1.0

#initial value of PSX
xi<<-t(mvrnorm(N,mu=rep(0,NZ),Sigma=PHI)) # NZ*N
PSX<<-matrix(0.0,nrow=NY,ncol=NY)
diag(PSX)<-1.0

#initial value of PHI^(-1)
inv.PHI<-chol2inv(chol(PHI))

#initial value of PHI^(-1/2)
c.inv.PHI<-chol(inv.PHI)

#initial value of PSX^(-1)
inv.PSX<-chol2inv(chol(PSX))

#initial value of PSX^(-1/2)
inv.sqrt.PSX<-chol(inv.PSX)


if(IDMUA==F) MU<-rep(0,NY)

# initial values for missing data in Y

for(i in 1:NY)
   for(j in 1:N)
      if(is.na(Y[i,j])) Y[i,j]<-rnorm(1)



### gibbs sampling  ##########################################################
for(g in 1:MCMAX){

    gm<-g
	gm2<-g-N.burn

    #Generate the latent factors from its conditinal distribution
    #source("Gibbs_Omega.R")
		##################  update Omega ##############################################################
    	ISG<-crossprod(inv.sqrt.PSX%*%LY)+inv.PHI
		SIG<-chol2inv(chol(ISG))
		Ycen<-Y
		if(IDMUA==T) Ycen<-Y-MU
		Mean<-SIG%*%t(LY)%*%inv.PSX%*%Ycen
		for(i in 1:N) Omega[,i]<-xi[,i]<-mvrnorm(1, Mean[,i], Sigma=SIG)
		##################  end of update Omega #######################################################


    #Generate the unknown parameter of intercept in CFA from its conditinal distribution
    #source("Gibbs_MU.R")
		###################    update MU  #################################################################
		if(IDMUA==T){

			calsm<-chol2inv(chol(N*inv.PSX+diag(rep(sigmu,NY)))) # inv[sigma0^(-1)+N*inv.PSX]
			Ycen<-Y-LY%*%Omega
			temp<-rowSums(Ycen)
			mumu<-calsm%*%(inv.PSX%*%temp+rep(sigmu,NY)*PMU)
			MU<-mvrnorm(1,mumu,Sigma=calsm)
					}
		###################    end of update MU  ##########################################################

    #Generate the unknown parameter of covariance matrix of measurement errors in CFA from its conditinal distribution
    #source("Gibbs_PSX.R")
		###################    update PSX  #################################################################
		temp<-Y-MU-LY%*%Omega  # NY*N
		S<-temp%*%t(temp)      # NY*NY

		apost<-a_lambda+NY*(NY+1)/2;

		#sample lambda
		bpost<-b_lambda + sum(abs(inv.PSX))/2  # C is the presicion matrix
		lambda<- rgamma(1, shape=apost, rate=bpost)

		#sample tau off-diagonal
		Cadjust<-pmax(abs(inv.PSX[upperind]),10^(-6))
		mu_prime<-pmin(lambda/Cadjust, 10^12)
		lambda_prime<-lambda^2
		tau_temp<-rep(0,length(mu_prime))
		for(i in 1:length(mu_prime)){
		tau_temp[i]<-1/rinvgauss(1, mean=mu_prime[i], dispersion=1/lambda_prime)
		}
		tau[upperind]<-tau_temp
		tau[lowerind]<-tau_temp

		#sample PSX and inv(PSX)
		for(i in 1:NY){

			ind_noi<-ind_noi_all[,i]
			tau_temp1<-tau[ind_noi,i]
			Sig11<-PSX[ind_noi, ind_noi]
			Sig12<-PSX[ind_noi,i]
			invC11<-Sig11-Sig12%*%t(Sig12)/PSX[i,i]
			Ci<-(S[i,i]+lambda)*invC11+diag(1/tau_temp1)
			Sigma<-chol2inv(chol(Ci))
			mu_i<--Sigma%*%S[ind_noi,i]
			beta<-mvrnorm(1,mu_i,Sigma)
			inv.PSX[ind_noi,i]<-beta
			inv.PSX[i,ind_noi]<-beta
			gam<-rgamma(1, shape=N/2+1, rate=(S[i,i]+lambda)/2)
			inv.PSX[i,i]<-gam+t(beta)%*%invC11%*%beta

			# below updating covariance matrix according to one-column change of precision matrix
				invC11beta<-invC11%*%beta
				PSX[ind_noi,ind_noi]<-invC11+invC11beta%*%t(invC11beta)/gam
				Sig12<--invC11beta/gam
				PSX[ind_noi, i]<-Sig12
				PSX[i,ind_noi]<-t(Sig12)
				PSX[i,i]<-1/gam
			} # end of i, sample Sig and C=inv(Sig)
		inv.sqrt.PSX<-chol(inv.PSX)
		##################  end of update PSX ##########################################################


    #Generate the unknown parameter of factor loading matrix in CFA from its conditinal distribution
    #source("Gibbs_LY.R")
		##################  update LY ##############################################################
		count.n<-1
		for(j in 1:NY){

			subs<-(IDY[j,]==1)
			len<-length(LY[j,subs])

			Ycen<-Y[j,]-MU[j]  # 1*N
			#Ycen<-Ycen-matrix(LY[j,(!subs),drop=F],nrow=1)%*%matrix(Omega[(!subs),,drop=F],ncol=N) # 1*N
			temp1<-chol2inv(chol(PSX[-j,-j]))
			Ycen<-Ycen-matrix(LY[j,(!subs)],nrow=1)%*%matrix(Omega[(!subs),],ncol=N)-PSX[j,-j]%*%temp1%*%(Y[-j,]-MU[-j]-LY[-j,]%*%Omega) # 1*N
			Ycen<-as.vector(Ycen) # vector

			if(len>0){

			if(len==1){omesub<-matrix(Omega[subs,],nrow=1)}
			if(len>1){omesub<-Omega[subs,]}
			PSiginv<-diag(len)
			diag(PSiginv)<-rep(sigly,len)
			Pmean<-PLY[j,subs]
			convar<-PSX[j,j]-PSX[j,-j]%*%chol2inv(chol(PSX[-j,-j]))%*%PSX[-j,j]
			invconvar<-chol2inv(chol(convar))
			calsmnpsx<-chol2inv(chol(invconvar%*%tcrossprod(omesub)+PSiginv))
			temp<-(omesub%*%Ycen%*%invconvar+PSiginv*Pmean)
			LYnpsx<-calsmnpsx%*%temp
			LY[j,subs]<-mvrnorm(1,LYnpsx,Sigma=(calsmnpsx))
			if((gm>0)&&(gm%%nthin==0)){ELY[gm/nthin,count.n:(count.n+len-1)]<-LY[j,subs]}
			count.n<-count.n+len

			} # end len>0
		} # end of NY
		##################  end of update LY ########################################################

    #Generate the unknown parameter of covariance matrix of latent factors in CFA from its conditinal distribution
    #source("Gibbs_PHI.R")
		########  update PHI ########################################################
		inv.PHI<-rwish(rou.zero+N, solve(tcrossprod(Omega)+R.zero))
		PHI<-chol2inv(chol(inv.PHI))
		c.inv.PHI<-chol(inv.PHI)
		########  end of update PHI #################################################

    #Generate the missing reponse in CFA from its conditinal distribution
    #source("Gibbs_MISY.R")
		for(j in 1:NY)
		for(i in 1:N)
			if(missing_ind[j,i]==1){
				mean<-MU[j]+LY[j,]%*%Omega[,i]+PSX[j,-j]%*%chol2inv(chol(PSX[-j,-j]))%*%(Y[-j,i]-MU[-j]-LY[-j,]%*%Omega[,i])
				var<-PSX[j,j]-PSX[j,-j]%*%chol2inv(chol(PSX[-j,-j]))%*%PSX[-j,j]
				Y[j,i]<-rnorm(1, mean, var)
			}



    #Save results
    if((gm>0)&&(gm%%nthin==0)){
       gm<-gm/nthin
       EPHI[gm,]<-as.vector(PHI[,])
       EPSX[gm,,]<-PSX
       EinvPSX[gm,,]<-inv.PSX
       EMU[gm,]<-MU
	  
       k<-1
       for(i in 1:NY){
          for(j in 1:NY){
            if(i>=j) {chainpsx[gm,k]<-PSX[i,j];k<-k+1}
          }
        }


	   if (gm2>0)
	   {
		  #Calculate PP p-value
          # source("Postp.R")
		postp1<-0.0
		postp2<-0.0
		Y.temp<-array(0, dim=c(NY,N))
		Y.cen<-Y-MU-LY%*%Omega # NY*N
		for(i in 1:N){
			postp1<-postp1+t(Y.cen[,i])%*%inv.PSX%*%Y.cen[,i]
		}

		xi.temp<-t(mvrnorm(N,mu=rep(0,NZ),Sigma=PHI))
		theta.temp<-MU+LY%*%xi.temp  # NY*N
		for(i in 1:N) Y.temp[,i]<-mvrnorm(1, theta.temp[,i], Sigma=PSX)
		Y.cen<-Y.temp-MU-LY%*%xi.temp  # NY*N
		Y_missing[,,gm] = Y.temp[,] 
		for(i in 1:N){
			postp2<-postp2+t(Y.cen[,i])%*%inv.PSX%*%Y.cen[,i]
		}
		if(postp1<=postp2) Epostp[gm]<-1.0;
		}

     }


    if(g%%100==0 && CIR == 1)cat(paste("Num of Iterations: ",g,"\n"),file="log.txt",append=T)


}#end of g MCMAX

chainlist<-list(EMU=EMU,ELY=ELY,EPHI=EPHI,EPSX=EPSX,Epostp=Epostp,EinvPSX=EinvPSX,chainpsx=chainpsx,
	missing_ind=missing_ind,Y_missing=Y_missing)
return(chainlist)

}
