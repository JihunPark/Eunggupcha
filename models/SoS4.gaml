/**
* Name: SoS
* Author: Jihun
* Description: 
* Tags: Tag1, Tag2, TagN
* This is a refactored version
*/

model SoS

experiment 'Batch Exp' type:gui {
	int maxCycle <- 5000;
	int nRun <- 25;
	
	/* Fixed Variables */
	int fixedPolicy <- 1;
	int fixedNPublicAmbulance <- 6;
	int fixedNPrivateAmbulance <- 0;
	int fixedNCar <- 0;
	float fixedPatientCreationProbability <- 0.20;	
	
	/* Discarded Simulation */
	parameter name:"policy:" var:policy init:0;
	parameter name:"nPublicAmbulance:" var:nPublicAmbulance init:0;
	parameter name:"nPrivateAmbulance:" var:nPrivateAmbulance init:0;
	parameter name:"nCar:" var:nCar init:0;
	parameter name:"patientCreationProbability:" var:patientCreationProbability init:0.00;
	
	init {
		list<float> simParamValues <- //[0.30, 0.35, 0.40, 0.45, 0.50];
//									   [0.05, 0.10, 0.15, 0.20, 0.25];
									   [0.55, 0.60, 0.65, 0.70, 0.75];
//									   [0.80, 0.85, 0.90, 0.95, 1.00];
		
		float tPatientProbability <- 0.00; 
		
		loop tPatientProbability over: simParamValues {
			loop times: nRun {
				create simulation with: [seed::rnd(1000), policy::fixedPolicy,
										 nPublicAmbulance::4, nPrivateAmbulance::1, nCar::fixedNCar,
										 patientCreationProbability::tPatientProbability];
			}
		}
		
//		loop i from: 0 to: 20 {
//			tPatientProbability <- i / 20;
//			loop times: nRun {
//				create simulation with: [seed::rnd(1000), policy::fixedPolicy,
//										 nPublicAmbulance::4, nPrivateAmbulance::1, nCar::fixedNCar,
//										 patientCreationProbability::tPatientProbability];
//			}
//		}
	}
	
  	reflex stopExp {
  		if(cycle >= maxCycle){
  			// stop simulation models
  			ask SoS_model {
  				do pause;
  			}
  			
  			// generate the filename for exp result with unique ID(date-based)
  			date firstdate <- date("2016-8-31T0:00:0+09:00");
  			date today <- date("now");
  			string resultID <- string(int(today - firstdate));
  			string filename <- "../results/" + resultID + "_result.csv";
  			
  			// write header to the result CSV file
			save ["Simulation", "Policy", "nPublic", "nPrivate", "nCar", "PatientProb", "nPatient",
				  "nPublicSaved", "nPrivateSaved", "nCarSaved","nTotalSaved",
				  "nDead", "nAlive",
				  "PublicCost", "PrivateCost", "TotalCost"
				 ] to:filename type:"csv" header:false; // useful facet - rewrite: true
			
			// write data to the result file & stop simulations
			int iGroup <- 0;
			float avgNPublicAmbulance <- 0.00;
			float avgNPrivateAmbulance <- 0.00;
			float avgNCar <- 0.00;
			float avgPatientCreated <- 0.00;
			float avgPublicSaved <- 0.00;
			float avgPrivateSaved <- 0.00;
			float avgCarSaved <- 0.00;
			float avgTotalSaved <- 0.00;
			float avgPatientDead <- 0.00;
			float avgPatientAlive <- 0.00;
			float avgCostOfPublicAmbulance <- 0.00;
			float avgCostOfPrivateAmbulance <- 0.00;
			float avgTotalCost <- 0.00;
			
  			loop sim over: SoS_model where (each.name != 'Simulation 0') {
  				if (mod(iGroup, nRun) = 0) {
  					iGroup <- 0;
  					avgNPublicAmbulance <- 0.00;
  					avgNPrivateAmbulance <- 0.00;
					avgNCar <- 0.00;
					avgPatientCreated <- 0.00;
					avgPublicSaved <- 0.00;
					avgPrivateSaved <- 0.00;
					avgCarSaved <- 0.00;
					avgTotalSaved <- 0.00;
					avgPatientDead <- 0.00;
					avgPatientAlive <- 0.00;
					avgCostOfPublicAmbulance <- 0.00;
					avgCostOfPrivateAmbulance <- 0.00;
					avgTotalCost <- 0.00;
  				}
  				
  				avgNPublicAmbulance <- avgNPublicAmbulance + sim.nPublicAmbulance;
  				avgNPrivateAmbulance <- avgNPrivateAmbulance + sim.nPrivateAmbulance;
  				avgNCar <- avgNCar + sim.nCar;
  				avgPatientCreated <- avgPatientCreated + sim.cntPatientCreated;
  				avgPublicSaved <- avgPublicSaved + sim.cntPublicSaved;
  				avgPrivateSaved <- avgPrivateSaved + sim.cntPrivateSaved;
  				avgCarSaved <- avgCarSaved + sim.cntCarSaved;
  				avgTotalSaved <- avgTotalSaved + (sim.cntPublicSaved + sim.cntPrivateSaved + sim.cntCarSaved);
  				avgPatientDead <- avgPatientDead + sim.cntPatientDead;
  				avgPatientAlive <- avgPatientAlive + length(sim.patient);
				avgCostOfPublicAmbulance <- avgCostOfPublicAmbulance + sim.costOfPublicAmbulance;
				avgCostOfPrivateAmbulance <- avgCostOfPrivateAmbulance + sim.costOfPrivateAmbulance;
				avgTotalCost <- avgTotalCost + (sim.costOfPublicAmbulance+sim.costOfPrivateAmbulance);
  				
				save [sim.name, sim.policy, sim.nPublicAmbulance, sim.nPrivateAmbulance, sim.nCar, sim.patientCreationProbability, sim.cntPatientCreated,
	  				  sim.cntPublicSaved, sim.cntPrivateSaved, sim.cntCarSaved, (sim.cntPublicSaved + sim.cntPrivateSaved + sim.cntCarSaved),
					  sim.cntPatientDead, length(sim.patient),
	  				  sim.costOfPublicAmbulance, sim.costOfPrivateAmbulance, (sim.costOfPublicAmbulance+sim.costOfPrivateAmbulance)
	  				 ] to:filename type:"csv" header:false;
	  			
	  			if (mod(iGroup, nRun) = nRun - 1) {
	  				save ['AveragedSim', sim.policy, avgNPublicAmbulance/nRun, avgNPrivateAmbulance/nRun, avgNCar/nRun, sim.patientCreationProbability,
					  avgPatientCreated/nRun,
	  				  avgPublicSaved/nRun, avgPrivateSaved/nRun, avgCarSaved/nRun, avgTotalSaved/nRun,
					  avgPatientDead/nRun, avgPatientAlive/nRun,
	  				  avgCostOfPublicAmbulance/nRun, avgCostOfPrivateAmbulance/nRun, avgTotalCost/nRun
	  				 ] to:filename type:"csv" header:false;
	  			}
	  			
	  			iGroup <- iGroup + 1;
	  		}
  		}
  	}
}

experiment 'GUI Exp' type:gui{
	int maxCycle <- 1000;
	
	//Parameters for simulation 0
	parameter name:"nCar:" var:nCar init:0;
	parameter name:"nPublicAmbulance:" var:nPublicAmbulance init:5;
	parameter name:"nPrivateAmbulance:" var:nPrivateAmbulance init:0;
//	parameter name:"nHospital:" var:nPrivateAmbulance init:0;
	parameter name:"policy:" var:policy init:1;	
	
  	output {
    	display GUI type:opengl {
    	  	species road aspect:geom;
			species building aspect:geom;
			species patient;
    	  	species EmergencyCar;
    	  	species hospital;
    	  	species publicAmbulance;
    	  	species privateAmbulance;
    	  	species car;
    	}
    	
    	display PatientChart refresh: every(10) {
			chart "Patients" type: series {
				data "patient made" value: cntPatientCreated color: #black;
				data "patient saved by public ambulance" value: cntPublicSaved color: #blue;
				data "patient saved by private ambulance" value: cntPrivateSaved color: #purple;
				data "patient saved by car" value: cntCarSaved color: #green;
				data "patient dead" value: cntPatientDead color: #red;
			}
		}
		
		display CostChart refresh: every(10) {
			chart "Costs" type: series {
				data "total costs" value: costOfPrivateAmbulance+costOfPublicAmbulance color: #black;
				data "costs of public ambulance" value: costOfPublicAmbulance color: #blue;
				data "costs of private ambulance" value: costOfPrivateAmbulance color: #green;	
			}
		}
  	}
  	
  	reflex stopExp {
  		if(cycle >= maxCycle){
  			ask SoS_model {
  				do pause;
  			}
  		}
  	}
}


global {
	/* Result Variables */
	bool printLog <- false; // Log
	
	int cntPatientCreated <- 0;
	int cntPublicSaved <- 0;
	int cntPrivateSaved <- 0;
	int cntCarSaved <- 0;
	int cntPatientDead <- 0;
	
	int costOfPublicAmbulance <-0;
	int costOfPrivateAmbulance <-0;
	
	/* Parameters */
	int policy <- 1; //1: Nearest, 2: FIFO, 3: Critical ASC
	int nPublicAmbulance <- 3;
	int nPrivateAmbulance <- 3;
	int nCar <- 0;
	int askingPrivateAmbulanceThreshold <- 20; // waiting time until private ambulance call
	
	int nHospital <- 4;
	list<point> locHospital <- [{414, 342}, {123, 775}, {383, 657}, {630, 683}];
	
	float patientCreationProbability <- 0.3;  
	
	int costPublicAmbulancePerTick <- 1;
	int costPrivateAmbulancePerEvent <- 50;
	
	float ambulanceSpeed <- 80 #km / #h;
	float carSpeed <- 50 #km / #h;
	
	/* Constants */
	int ambulanceSearchDistance <- 2000;
	int carSearchDistance <- 20;
	
	/* World Geometry */	
	string patientFile const: true <- '../images/patient.jpg' ;
	string ambulanceFile const: true <- '../images/ambulance.png' ;
	string pAmbulanceFile const: true <- '../images/pAmbulance.jpg' ;
	string hospitalFile const: true <- '../images/hospital.png' ;
	string carFile const: true <- '../images/car.png' ;
	
	file roads_shapefile <- file("../includes/road.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	geometry shape <- envelope(roads_shapefile);
	graph road_network;
	
	init {
		// create world
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		create building from: buildings_shapefile;
    	
    	loop i from:0 to: nHospital - 1 {
    		create hospital {
	    		building bd <- (building) closest_to (locHospital[i]);
	    		location<- any_location_in(bd);
    		}
    	}
		
		create publicAmbulance number: nPublicAmbulance {
    		speed <- ambulanceSpeed; 
    	  	hospital bd <- one_of(hospital);
			location <- any_location_in(bd);      
   		}
   		
   		create privateAmbulance number: nPrivateAmbulance {
    		speed <- ambulanceSpeed; 
    	  	building bd <- one_of(building);
			location <- any_location_in(bd);      
   		}    
   		
   		create car number: nCar {
    		speed <- carSpeed; 
    	  	building bd <- one_of(building);
			location <- any_location_in(bd);      
   		}    
  	}
  	
  	reflex createPatient {
  		if (flip(patientCreationProbability)) {
  			create patient {
  				cntPatientCreated <- cntPatientCreated + 1;
  				building bd<-one_of(building);
  				location<- bd.location;
  			}
  		}
  	}
}

species road {
	aspect geom {
		draw shape color: #black;
	}
}
species building {
	aspect geom {
		draw shape color: #gray;
	}
}
species hospital {
	aspect default {
		draw file(hospitalFile) size: {30, 30} ;
	}
}
species patient skills:[moving] {
	EmergencyCar rideEmergencyCar;
	EmergencyCar waitingAmbulance;
	bool inHospital;
	bool isTargeted;
	
	int timeAlive;
	int waiting;
	
	init{
		timeAlive <- 100 + rnd(20);
		waiting <- 0;
		if(printLog){
			if(policy = 3) {
				write "make patient "+self.name+"! - initial timeAlive: "+timeAlive;
			} else {
				write "make patient "+self.name+"!";
			}
		}
	}
	
	reflex dying{
		timeAlive <- timeAlive - 1;
		if(timeAlive<=30){
			draw circle(20) color:#red;
		}
		
		if(timeAlive<=0){
			if(printLog){write self.name+" is dead";}
			cntPatientDead <- cntPatientDead+1;
			
			if(isTargeted){
				ask waitingAmbulance{
					targetPatient<-nil;
				}
			}
			if(rideEmergencyCar!=nil){
				ask rideEmergencyCar{
					targetPatient<-nil;
					ridePatient<-nil;
				}
			}
			do die;
		}
		
		// patient 가 Target 되지 않고 기다린 시간이 일정 시간이상이 되면 private Ambulance (Acknowledged type) 를 부름
		if(rideEmergencyCar=nil and waitingAmbulance=nil){
			waiting <- waiting+1;
			
			if(waiting > askingPrivateAmbulanceThreshold and nPrivateAmbulance > 0){
			// private ambulance 요청
//			privateAmbulance askPAmbulance <- (privateAmbulance) closest_to (self);
			
				privateAmbulance askPAmbulance <- nil;
				
				loop d from:1 to:ambulanceSearchDistance{
					privateAmbulance candidate <- one_of (privateAmbulance at_distance d);
					if (candidate!=nil and candidate.targetPatient=nil and candidate.ridePatient=nil){
						askPAmbulance <- candidate;
						if(printLog){write self.name+": "+candidate.name+" at distance of "+d+" will save myself";}
						break;
					}
				}
				
				if(askPAmbulance!=nil){
					ask askPAmbulance{
						targetPatient<-myself;
					}
					isTargeted <- true;
					waitingAmbulance <- askPAmbulance;
					
					costOfPrivateAmbulance <- costOfPrivateAmbulance + costPrivateAmbulancePerEvent;
				}
			}
		}
		
		if(waitingAmbulance!=nil and waitingAmbulance.targetPatient!=self){
			if(printLog){write "[Error2]: "+self.name+" is waiting "+waitingAmbulance+", but it is not targeting this patient.";}
		}
	}
	
	action recover {
		if (rideEmergencyCar is publicAmbulance){
			cntPublicSaved <- cntPublicSaved+1;
		}
		if (rideEmergencyCar is privateAmbulance){
			cntPrivateSaved <- cntPrivateSaved+1;
		}
		if (rideEmergencyCar is car){
			cntCarSaved <- cntCarSaved+1;
		}
		
		inHospital<-true;
		rideEmergencyCar<-nil;
		waitingAmbulance<-nil;
		isTargeted<-false;
		
		do die;
	}
	
	aspect default{
		draw  file(patientFile) rotate: heading at: location size: {15,15} ;
	}
}

species EmergencyCar skills:[moving] {
	patient targetPatient;
	patient ridePatient;
	hospital targetHospital;
	
	/**
	 * 흐름도
	 * Collaborative: Set target (random building) -> Move to target (목표 빌딩으로 이동) -> Find patient (주변에 환자가 있으면 발견) -> Move with Patient (가까운 병원으로 이동)
	 * Acknowloged: Set target (Policy에 따라 환자 찾음) -> Move to patient->Move with patient (cost analysis 말고는 Directed랑 똑같아짐) 
	 * Directed: Set target (Policy에 따라 타겟환자 찾음) -> Move to patient (타겟환자에게 이동) -> Move with Patient (환자와 병원으로 이동)
	 * 
	 * 실험1: All directed vs. All collaborative vs. Mixed 의 생존율 비교  
	 * 실험2: All directed vs. Directed+Acknowledged 의 비용 비교 (Directed 는 일급, Acknowledged 는 건당 급여)
	 * 
	 */
	
	reflex moveWithPatient when: targetPatient=nil and ridePatient!=nil{
		do goto target:targetHospital.location on: road_network;
		
		ask ridePatient{
			location <- myself.location;
		}
		
//		if(location = targetHospital.location){
		if(location distance_to targetHospital.location < 3){	
			do releasePatient;
		}
	}
	
	action pickPatient{
		ridePatient <- targetPatient;
		targetHospital <- hospital closest_to(self); // 환자에게 가장 가까운 병원으로 목적지 설정
		ask ridePatient{
			rideEmergencyCar <- myself;
			waitingAmbulance <- nil;
		}
		targetPatient <- nil;
		
		if(printLog){write self.name+": I just pick patient "+ridePatient.name+" and this patient will be delivered to "+targetHospital.name;}
	}
	
	action releasePatient{
		if(printLog){write self.name+": "+ridePatient.name+" is delivered to "+targetHospital.name+".";}
		
		ask ridePatient{
			do recover;
		}
		
//		if(self is privateAmbulance){
//			costOfPrivateAmbulance <- costOfPrivateAmbulance + costPrivateAmbulancePerEvent;
//		}
		
		ridePatient <- nil;
		targetHospital<-nil;
		targetPatient <- nil;
	}
	
	aspect default{
//		draw file(ambulanceFile) size:{20,20};
		draw circle(5) color:#red;
	}
}

species publicAmbulance parent:EmergencyCar {
	reflex cost {
		costOfPublicAmbulance <- costOfPublicAmbulance + costPublicAmbulancePerTick;
	}
	
	reflex setTarget when: targetPatient = nil and ridePatient = nil {
		do findTarget;
	}
	
	reflex moveToPatient when: targetPatient != nil and ridePatient = nil{
		do goto target:targetPatient.location on: road_network;//on: road_network;
		if (location = targetPatient.location) {
			do pickPatient;
		}
	}
	
	action findTarget{
		if(targetPatient!=nil){
			if(printLog){write "[ERROR1] "+self.name+" has target patient, but it is trying to find target.";}
		}
		
		// 기본 조건: 뭔가 타고 있지 않고, 나랑 위치가 같지 않음. 다른 ambulance 에 의해 target 되지 않음
		
		if(policy = 1) {
			// Policy1: 환자가 생기는 순서대로 구하기
			patient candidate <- first_with (patient, !each.inHospital and each.rideEmergencyCar=nil and !each.isTargeted);
			targetPatient <- candidate;
			if(printLog){write self.name+": patient "+targetPatient.name+" will be saved by me by the rule of FIFO";}
		} else if(policy = 2) {
			// Policy2 : 제일 가까운 patient 를 고름
			loop d from:1 to:ambulanceSearchDistance {
				patient candidate <- one_of (patient at_distance d);
				if (candidate!=nil and !candidate.inHospital and candidate.rideEmergencyCar=nil and !candidate.isTargeted){
					targetPatient <- candidate;
					if(printLog){write self.name+": patient "+targetPatient.name+" at distance of "+d+" will be saved by me";}
					break;
				}
			}
		} else if(policy = 3) {
			// Policy3: 환자의 생명력이 짧은 순서대로 구하기
			list<patient> sortedlist <- (where(patient, !each.inHospital and each.rideEmergencyCar=nil and !each.isTargeted) sort_by (each.timeAlive));
			if(length(sortedlist) > 0) {
				patient candidate <- sortedlist[0];
				targetPatient <- candidate;
				if(printLog){write self.name+": patient "+targetPatient.name+" with timeAlive of "+targetPatient.timeAlive+" will be saved by me";}
			}
		}
		
		if(targetPatient!=nil){
			ask targetPatient{
				isTargeted <- true;
				waitingAmbulance <- myself;
			}
		}
	}
	
	aspect default{
		draw file(ambulanceFile) size:{20,20};
	}
}

species privateAmbulance parent:EmergencyCar {
	reflex moveToPatient when: targetPatient != nil and ridePatient = nil{
		do goto target:targetPatient.location on: road_network;//on: road_network;
		if (location = targetPatient.location) {
			do pickPatient;
		}
	}
	
	aspect default{
		draw file(pAmbulanceFile) size:{20,20};
	}
}

species car parent:EmergencyCar {
	// Collaborative: Set target (random building) -> Move to target (목표 빌딩으로 이동) -> Find patient (주변에 환자가 있으면 발견) -> Move with Patient (가까운 병원으로 이동)
	
	building targetBuilding;
	
	reflex setTargetBuilding when: targetBuilding = nil and ridePatient = nil {
		// 갈 데가 없으면 갈 데를 찾음
		targetBuilding <- one_of(building);
	}
	
	reflex moveToTarget when: targetBuilding !=nil and ridePatient = nil{
		// 원래 자기 목적지로 감
		do goto target:targetBuilding.location on: road_network;//on: road_network;
		
		
		building closestBuilding <- building closest_to (self);
		patient closestPatient <- patient closest_to (self);
		
		loop d from:1 to:carSearchDistance{
			building candidateBuilding <- one_of (building at_distance d);
			patient candidate <- patient closest_to(self);
			
			if(candidateBuilding!=nil and candidate!=nil){ 
			if(candidate.location = candidateBuilding.location){
				if (candidate!=nil and !candidate.inHospital and candidate.rideEmergencyCar=nil and !candidate.isTargeted){
					targetPatient <- candidate;
					do pickPatient;
					if(printLog){write self.name+": patient "+candidate.name+" at distance of "+d+" will be saved by me";}
					break;
				}				
			}
			}
		}
		
		if(location=targetBuilding.location){	
			targetBuilding <- nil;
		}
	}
	
	
	aspect default{
//		draw circle(50) color:#green;
		draw file(carFile) size:{20,20};
	}
}
