/**
* Name: SoS
* Author: Jihun
* Description: 
* Tags: Tag1, Tag2, TagN
* commit test
*/

model SoS

global{
//	float step <- 1 #minutes;
	
	int nCar<-0;
	int nAmbulance<-3;
	int nPrivateAmbulance<-3;
//	int nHospital<-5;
	
	int maxCycle<-1000;
	int policy<-3;
	// Policy1 : 제일 가까운 patient 를 고름
	// Policy2: 환자가 생기는 순서대로 구하기
	// Policy3: 환자의 생명력이 짧은 순서대로 구하기
	
	int maxSearchDistance <- 2000;
	int privateCarSearchDistance <- 20;
	
	int askingPrivateAmbulanceThreshold <- 20;
	
	string patientFile const: true <- '../images/patient.jpg' ;
	string ambulanceFile const: true <- '../images/ambulance.png' ;
	string pAmbulanceFile const: true <- '../images/pAmbulance.jpg' ;
	string hospitalFile const: true <- '../images/hospital.png' ;
	string carFile const: true <- '../images/car.png' ;
	
	file roads_shapefile <- file("../includes/road.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	geometry shape <- envelope(roads_shapefile);
	graph road_network;
	
	float carSpeed <- 50 #km / #h;
	float ambulanceSpeed <- 80 #km / #h;
	float makePatientProbability <- 0.3;
	
	int nb_patient_made <- 0;
	int nb_patient_saved_by_ambulance <- 0;
	int nb_patient_saved_by_pAmbulance <- 0;
	int nb_patient_saved_by_car <- 0;
	int nb_patient_dead <- 0;
	
	int costPublicAmbulancePerTick <- 1;
	int costPrivateAmbulancePerEvent <- 50;
	
	int costOfPublicAmbulance <-0;
	int costOfPrivateAmbulance <-0;
	
	init {
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		
		create building from: buildings_shapefile; 
		
//    	create hospital number: nHospital {
//    	  building bd <- one_of(building);
//			location <- any_location_in(bd);          
//    	}
    	
    	create hospital {
    		building bd <- (building) closest_to ({414, 342});
    		location<- any_location_in(bd);
    	}create hospital {
    		building bd <- (building) closest_to ({123, 775});
    		location<- any_location_in(bd);
    	}create hospital {
    		building bd <- (building) closest_to ({383, 657});
    		location<- any_location_in(bd);
    	}create hospital {
    		building bd <- (building) closest_to ({630, 683});
    		location<- any_location_in(bd);
    	}

		create publicAmbulance number: nAmbulance {
    		speed <- ambulanceSpeed; 
    	  	hospital bd <- one_of(hospital);
			location <- any_location_in(bd);      
   		}
   		
   		create privateAmbulance number: nPrivateAmbulance {
    		speed <- ambulanceSpeed; 
    	  	building bd <- one_of(building);
			location <- any_location_in(bd);      
   		}    
   		
   		create privateCar number: nCar {
    		speed <- carSpeed; 
    	  	building bd <- one_of(building);
			location <- any_location_in(bd);      
   		}    
  	}
  	
  	reflex makePatient{
  		if(flip(makePatientProbability)){
  			// creation log is moved to init() of Patient species
  			create patient {
  				building bd<-one_of(building);
  				location<- bd.location;
  				nb_patient_made <- nb_patient_made+1;
  			}
  		}
  	}
  	
  	reflex stop{
  		int cycle_ <- cycle;
  		
  		if(cycle > maxCycle){
  			write ""+nb_patient_made+" patients made, "+nb_patient_saved_by_ambulance+" patients are saved by ambulance, "
  				+nb_patient_saved_by_car+" patients are saved by car, "+nb_patient_dead+" patients dead.";
  			do pause;
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

species hospital{
	aspect default{
		draw  file(hospitalFile) size: {30,30} ;
	}
}

species patient skills:[moving]{
	EmergencyCar rideEmergencyCar;
	EmergencyCar waitingAmbulance;
	bool inHospital;
	bool isTargeted;
	
	int timeAlive;
	int waiting;
	
	init{
		timeAlive <- 100 + rnd(20);
		waiting <- 0;
		if(policy = 3) {
			write "make patient "+self.name+"! - initial timeAlive: "+timeAlive;
		} else {
			write "make patient "+self.name+"!";
		}
	}
	
	reflex dying{
		timeAlive <- timeAlive - 1;
		if(timeAlive<=30){
			draw circle(20) color:#red;
		}
		if(timeAlive<=0){
			write self.name+" is dead";
			nb_patient_dead <- nb_patient_dead+1;
			
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
			
			loop d from:1 to:maxSearchDistance{
				privateAmbulance candidate <- one_of (privateAmbulance at_distance d);
				if (candidate!=nil and candidate.targetPatient=nil and candidate.ridePatient=nil){
					askPAmbulance <- candidate;
					write self.name+": "+candidate.name+" at distance of "+d+" will save myself";
					break;
				}
			}
			
			if(askPAmbulance!=nil){
				ask askPAmbulance{
					targetPatient<-myself;
				}
				isTargeted <- true;
				waitingAmbulance <- askPAmbulance;
			}
			}
		}
		
		
		if(waitingAmbulance!=nil and waitingAmbulance.targetPatient!=self){
			write "[Error2]: "+self.name+" is waiting "+waitingAmbulance+", but it is not targeting this patient.";
		}
	}
	
	action recover {
		if (rideEmergencyCar is publicAmbulance){
			nb_patient_saved_by_ambulance <- nb_patient_saved_by_ambulance+1;
		}
		if (rideEmergencyCar is privateAmbulance){
			nb_patient_saved_by_pAmbulance <- nb_patient_saved_by_pAmbulance+1;
		}
		if (rideEmergencyCar is privateCar){
			nb_patient_saved_by_car <- nb_patient_saved_by_car+1;
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
		
		write self.name+": I just pick patient "+ridePatient.name+" and this patient will be delivered to "+targetHospital.name;
	}
	
	action releasePatient{
		write self.name+": "+ridePatient.name+" is delivered to "+targetHospital.name+".";
		
		ask ridePatient{
			do recover;
		}
		
		if(self is privateAmbulance){
			costOfPrivateAmbulance <- costOfPrivateAmbulance + costPrivateAmbulancePerEvent;
		}
		
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
			write "[ERROR1] "+self.name+" has target patient, but it is trying to find target.";
		}
		
		// 기본 조건: 뭔가 타고 있지 않고, 나랑 위치가 같지 않음. 다른 ambulance 에 의해 target 되지 않음
		
		if(policy = 1) {
			// Policy 1 : 제일 가까운 patient 를 고름
			loop d from:1 to:maxSearchDistance{
				patient candidate <- one_of (patient at_distance d);
				if (candidate!=nil and !candidate.inHospital and candidate.rideEmergencyCar=nil and !candidate.isTargeted){
					targetPatient <- candidate;
					write self.name+": patient "+targetPatient.name+" at distance of "+d+" will be saved by me";
					break;
				}
			}
		} else if(policy = 2) {
			// Policy2: 환자가 생기는 순서대로 구하기
			patient candidate <- first_with (patient, !each.inHospital and each.rideEmergencyCar=nil and !each.isTargeted);
			targetPatient <- candidate;
			write self.name+": patient "+targetPatient.name+" will be saved by me by the rule of FIFO";
		} else if(policy = 3) {
			// Policy3: 환자의 생명력이 짧은 순서대로 구하기
			list<patient> sortedlist <- (where(patient, !each.inHospital and each.rideEmergencyCar=nil and !each.isTargeted) sort_by (each.timeAlive));
			if(length(sortedlist) > 0) {
				patient candidate <- sortedlist[0];
				targetPatient <- candidate;
				write self.name+": patient "+targetPatient.name+" with timeAlive of "+targetPatient.timeAlive+" will be saved by me";
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

species privateCar parent:EmergencyCar {
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
		
		loop d from:1 to:privateCarSearchDistance{
			building candidateBuilding <- one_of (building at_distance d);
			patient candidate <- patient closest_to(self);
			
			if(candidateBuilding!=nil and candidate!=nil){ 
			if(candidate.location = candidateBuilding.location){
				if (candidate!=nil and !candidate.inHospital and candidate.rideEmergencyCar=nil and !candidate.isTargeted){
					targetPatient <- candidate;
					do pickPatient;
					write self.name+": patient "+candidate.name+" at distance of "+d+" will be saved by me";
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



experiment exp1 type:gui{
//	parameter "Initial number of patients: " var: nPatient min: 1 max: 1000 category: "Patients" ;	
	
  	output {
    	display GUI type:opengl {
    	  	species road aspect:geom;
			species building aspect:geom;
			species patient;
    	  	species EmergencyCar;
    	  	species hospital;
    	  	species publicAmbulance;
    	  	species privateAmbulance;
    	  	species privateCar;
    	}
    	
    	display PatientChart refresh: every(10) {
			chart "Patients" type: series {
				data "patient made" value: nb_patient_made color: #black;
				data "patient saved by public ambulance" value: nb_patient_saved_by_ambulance color: #blue;
				data "patient saved by private ambulance" value: nb_patient_saved_by_pAmbulance color: #purple;
				data "patient saved by car" value: nb_patient_saved_by_car color: #green;
				data "patient dead" value: nb_patient_dead color: #red;
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
}
