setwd("/Users/mattadmin/Desktop/RMAS_Example")
# 
#install.packages("remotes")
#remotes::install_github("nmfs-fish-tools/RMAS")

require(Rcpp)
require(RMAS)

library(jsonlite)

#load the r4mas module
d <- system.file(package = "RMAS")

if(.Platform$OS.type == "windows") {
  r4mas <-
    Module("rmas", dyn.load(paste(d,"/libs/x64/RMAS", .Platform$dynlib.ext, sep = "")))
}else{
  r4mas <-
    Module("rmas", dyn.load(paste(d,"/libs/RMAS", .Platform$dynlib.ext, sep = "")))
}


load("OM1.RData")

nyears<-om_input$nyr
nseasons<-1
nages<-om_input$nages
ages <- om_input$ages

#define area
area1<-new(r4mas$Area)
area1$name<-"area1"

#build the MAS model
mas_model<-new(r4mas$MASModel)
mas_model$nyears<-nyears
mas_model$nseasons<-nseasons
mas_model$nages<-nages
#Recruitment
recruitment<-new(r4mas$BevertonHoltRecruitment)
recruitment$R0$value<-om_input$R0/1000
recruitment$R0$estimated<-TRUE
recruitment$R0$phase<-1
recruitment$h$value<-om_input$h
recruitment$h$estimated<-FALSE
recruitment$h$phase<-3
recruitment$h$min<-0.02001
recruitment$h$max<-1.0
recruitment$sigma_r$value <- exp(om_input$logR_sd)
recruitment$sigma_r$estimated<-FALSE
recruitment$sigma_r$min<-0
recruitment$sigma_r$max<-1.0
recruitment$sigma_r$phase<-2
recruitment$estimate_deviations<-TRUE
recruitment$constrained_deviations<-FALSE
recruitment$deviations_min<--15.0
recruitment$deviations_max<-15.0
recruitment$deviation_phase<-1
recruitment$SetDeviations(rep(0.0, times=om_input$nyr))

#Growth
growth<-new(r4mas$VonBertalanffyModified)
empirical_weight<-rep(om_input$W.kg, times=om_input$nyr)
survey_empirical_weight<-replicate(nages*nyears, 1.0)
growth$SetUndifferentiatedCatchWeight(empirical_weight)
growth$SetUndifferentiatedSurveyWeight(survey_empirical_weight)
growth$SetUndifferentiatedWeightAtSeasonStart(empirical_weight)
growth$SetUndifferentiatedWeightAtSpawning(empirical_weight)
growth$a_min$value<-0.01
growth$a_max$value<-10.0
growth$c$value<-0.3
growth$lmin$value<-5
growth$lmax$value<-50
growth$alpha_f$value<-0.000025
growth$alpha_m$value<-0.000025
growth$beta_f$value<-2.9624
growth$beta_m$value<-2.9624

#Maturity
maturity<-new(r4mas$Maturity)
maturity$values <- om_input$mat.age*0.5

#Natural Mortality
natural_mortality<-new(r4mas$NaturalMortality)
natural_mortality$SetValues(om_input$M.age)
natural_mortality$estimate<-FALSE
natural_mortality$phase<-4

#define Movement (only 1 area in this model)
movement<-new(r4mas$Movement)
movement$connectivity_females<-c(1.0)
movement$connectivity_males<-c(1.0)
movement$connectivity_recruits<-c(1.0)

#Initial Deviations
initial_deviations<-new(r4mas$InitialDeviations)
initial_deviations$values<-rep(0, times=om_input$nages)
initial_deviations$estimate<-FALSE
initial_deviations$phase<-1

population<-new(r4mas$Population)
for (y in 0:(nyears))
{
  population$AddMovement(movement$id, y)
}

population$AddNaturalMortality(natural_mortality$id,area1$id,"undifferentiated")
population$AddMaturity(maturity$id,area1$id, "undifferentiated")
#population$AddRecruitment(recruitment$id, area1$id)
population$AddRecruitment(recruitment$id, 1, area1$id)
population$SetInitialDeviations(initial_deviations$id, area1$id, "undifferentiated")
population$SetGrowth(growth$id)
population$sex_ratio<-0.5

#Fishing Mortality
fishing_mortality<-new(r4mas$FishingMortality)
fishing_mortality$estimate<-TRUE
fishing_mortality$phase<-1
fishing_mortality$min<-0.0
fishing_mortality$max<-4
fishing_mortality$SetValues(om_output$f)

#Selectivity Model
fleet_selectivity<-new(r4mas$LogisticSelectivity)
fleet_selectivity$a50$value<-om_input$sel_fleet$fleet1$A50.sel
fleet_selectivity$a50$estimated<-TRUE
fleet_selectivity$a50$phase<-2
fleet_selectivity$a50$min<-0.0
fleet_selectivity$a50$max<-max(om_input$ages)

fleet_selectivity$slope$value<-1/om_input$sel_fleet$fleet1$slope.sel
fleet_selectivity$slope$estimated<-fleet_selectivity$a50$estimated
fleet_selectivity$slope$phase<-2
fleet_selectivity$slope$min<-0
fleet_selectivity$slope$max<-max(om_input$ages)

survey_selectivity<-new(r4mas$LogisticSelectivity)
survey_selectivity$a50$value<-om_input$sel_survey$survey1$A50.sel
survey_selectivity$a50$estimated<-TRUE
survey_selectivity$a50$phase<-2
survey_selectivity$a50$min<-0.0
survey_selectivity$a50$max<-max(om_input$ages)

survey_selectivity$slope$value<-1/om_input$sel_survey$survey1$slope.sel
survey_selectivity$slope$estimated<-survey_selectivity$a50$estimated
survey_selectivity$slope$phase<-2
survey_selectivity$slope$min<-0
survey_selectivity$slope$max<-max(om_input$ages)

#Index data
catch_index<-new(r4mas$IndexData)
catch_index$values<-em_input$L.obs$fleet1
#dat.input$cv.L
catch_index$error<-rep(em_input$cv.L$fleet1, times=om_input$nyr)

survey_index<-new(r4mas$IndexData)
survey_index$values<-em_input$survey.obs$survey1
survey_index$error<-rep(em_input$cv.survey$survey1, times=om_input$nyr)


#Age Comp Data
catch_comp<-new(r4mas$AgeCompData)
catch_comp$values<-as.vector(t(em_input$L.age.obs$fleet1))
catch_comp$sample_size <-rep(em_input$n.L$fleet1, nyears*nseasons)


survey_comp<-new(r4mas$AgeCompData)
survey_comp$values<-as.vector(t(em_input$survey.age.obs$survey1))
survey_comp$sample_size<-rep(em_input$n.survey$survey1, times=om_input$nyr)

#NLL models
fleet_index_comp_nll<-new(r4mas$Lognormal)
fleet_age_comp_nll<-new(r4mas$Multinomial)
#The other four models uses standard multinomial for age comp nll
survey_index_comp_nll<-new(r4mas$Lognormal)
survey_age_comp_nll<-new(r4mas$Multinomial)
#The other four models uses standard multinomial for age comp nll


#Fleet
fleet<-new(r4mas$Fleet)
fleet$AddAgeCompData(catch_comp$id, "undifferentiated")
fleet$AddIndexData(catch_index$id, "undifferentiated")
fleet$SetAgeCompNllComponent(fleet_age_comp_nll$id)
fleet$SetIndexNllComponent(fleet_index_comp_nll$id)
fleet$AddSelectivity(fleet_selectivity$id, 1, area1$id)
fleet$AddFishingMortality(fishing_mortality$id, 1,area1$id)


#Survey
survey<-new(r4mas$Survey)
survey$AddAgeCompData(survey_comp$id,"undifferentiated")
survey$AddIndexData(survey_index$id,"undifferentiated")
survey$SetIndexNllComponent(survey_index_comp_nll$id)
survey$SetAgeCompNllComponent(survey_age_comp_nll$id)
survey$AddSelectivity(survey_selectivity$id, 1, area1$id)
survey$q$value<-em_input$survey_q$survey1
survey$q$min<-0
survey$q$max<-10
survey$q$estimated<-TRUE
survey$q$phase<-1



#build the MAS model
mas_model<-new(r4mas$MASModel)
mas_model$nyears<-nyears
mas_model$nseasons<-nseasons
mas_model$nages<-nages
mas_model$extended_plus_group<-max(om_input$ages)
mas_model$ages<-ages
mas_model$AddFleet(fleet$id)
mas_model$catch_season_offset<-0
mas_model$spawning_season_offset<-0
mas_model$survey_season_offset<-0.0

mas_model$AddSurvey(survey$id)
mas_model$AddPopulation(population$id)
mas_model$Run()

write(mas_model$GetOutput(), file="rmas_example_output.json")



#read output
args <- commandArgs(trailingOnly = TRUE)
args <- "rmas_example_output.json"
json_output <- read_json(args[1])
popdy<-json_output$population_dynamics
years <- popdy$nyears
seasons<-popdy$nseasons
areas<-popdy$nareas
ages_ <- popdy$nages

#population
pop<-popdy$populations[[1]]
flt<-popdy$fleets[[1]]
srvy<-popdy$surveys[[1]]
area<-popdy$areas[[1]]
pop_naa<-pop$undifferentiated$numbers_at_age
pop_recruits<-pop$undifferentiated$recruits
pop_abundance<-pop$undifferentiated$abundance
pop_abundance_f<-pop$females$abundance
pop_abundance_m<-pop$males$abundance
pop_ssb<-pop$undifferentiated$spawning_stock_biomass
pop_biomass<-pop$undifferentiated$biomass
pop_F<-pop$undifferentiated$fishing_mortality
flt_landings<-flt$undifferentiated$catch_biomass
srvy_landings<-srvy$undifferentiated$survey_biomass
srvy_props<-srvy$undifferentiated$survey_proportion_at_age



# print(x)
plot_file<- "mas_example_true_estimate_timeseries.jpg"
# jpeg(toString(plot_file), width = 6, height = 4, units = 'in', res = 300)
 
x<-seq(1,30, 1)

par(mfrow=c(2,4))

#plot biomass
plot( x, unlist(pop_biomass$values), type="l", col="red"
      ,xlab = "Year" ,ylab="Biomass (mt)")
lines(x, om_output$biomass.mt,type="p")

#plot abundance
plot( x,unlist(pop_abundance$values), type="l", col="red"
      ,xlab = "Year",ylab="Abundance (1000 fish)")
lines(x, om_output$abundance/1000,type="p")

#plot spawning stock biomass
plot( x,om_output$SSB,type="p"
      ,xlab = "Year",ylab="SSB (mt)")
lines(x,unlist(pop_ssb$values) ,type="l", col="red")

#plot recruits
plot( x,unlist(pop_recruits$values), type="l", col="red"
      ,xlab = "Year",ylab="Recruitment (1000 fish)")
lines(x, om_output$N.age[,1]/1000,type="p")

#plot fishing mortality
plot( x,om_output$f, type="p"
      ,xlab = "Year",ylab="F")
lines(x, unlist(pop_F$values),type="l",col="red")

#plot fleet landings
plot( x,unlist(flt_landings$values), type="l", col="red"
      ,xlab = "Year",ylab="Landings (mt)")
lines(x, om_output$L.mt[1]$fleet1,type="p")

#plot survey index
plot( x,unlist(srvy_landings$values), type="l", col="red"
      ,xlab = "Year",ylab="Survey Index")
lines(x, om_output$survey_index[1]$survey1,type="p")
