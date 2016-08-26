/**
* Name: SoS
* Author: Jihun
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model SoS

global{
//	float step <- 1 #minutes;
	
	int nCar<-0;
	int nAmbulance<-1;
	int nHospital<-10;
	
	int maxSearchDistance <- 2000; // #MG# A unit is required here e.g., 2000 m or 2000 km
	int privateCarSearchDistance <- 20;
	
	string patientFile const: true <- '../images/patient.jpg' ;
	string ambulanceFile const: true <- '../images/ambulance.png' ;
	string hospitalFile const: true <- '../images/hospital.png' ;
	string carFile const: true <- '../images/car.png' ;
	
	file roads_shapefile <- file("../includes/road.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	geometry shape <- envelope(roads_shapefile); // #MG# shape for environment
	graph road_network;
	
	float carSpeed <- 50 #km / #h;
	float ambulanceSpeed <- 80 #km / #h;
	float makePatientProbability <- 0.3;
	
	int nb_patient_made <- 0;
	int nb_patient_saved_by_ambulance <- 0;
	int nb_patient_saved_by_car <- 0;
	int nb_patient_dead <- 0;
	
	init {
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		
		create building from: buildings_shapefile; 
		
		// 처음에 환자를 안만드는게 나을듯
//    	create patient number: nPatient { 
////    	  location <- {rnd(100), rnd(100)};
//			building bd <- one_of(building);
//			location <- any_location_in(bd);       
//    	} 

    	create hospital number: nHospital {
    	  	building bd <- one_of(building); // #MG# Temporal & local species
			location <- any_location_in(bd);          
    	}
//    	create EmergencyCar number: nAmbulance {

		create publicAmbulance number: nAmbulance {
    		speed <- ambulanceSpeed; 
    	  	hospital bd <- one_of(hospital); // #MG# Temporal & local species
			location <- any_location_in(bd);      
   		}
   		
   		create privateCar number: nCar {
    		speed <- ambulanceSpeed; 
    	  	building bd <- one_of(building);
			location <- any_location_in(bd);      
   		}    
  	}
  	
  	reflex makePatient{
  		if(flip(makePatientProbability)){
  			write "make patient!";
  			create patient {
  				building bd<-one_of(building);
  				location<- any_location_in(bd);
  				nb_patient_made <- nb_patient_made+1;
  			}
  		}
  	}
  	
  	reflex stop{
  		int cycle_ <- cycle;
  		
  		if(cycle > 1000){
  			write ""+nb_patient_made+" patients made, "+nb_patient_saved_by_ambulance+" patient saved, "+nb_patient_dead+" patients dead.";
  			do pause;
  		}
  		
  	}
}

species road {
	aspect geom { // #MG# Why isn't it the default? 
		draw shape color: #black;
	}
}
species building {
	aspect geom { // #MG# Why isn't it the default?
		draw shape color: #gray;
	}
}

species hospital { // #MG# Need to set its parent as 'building' ? (Nope - it is a kind of mark for the building)
	aspect default{
		draw  file(hospitalFile) size: {30,30} ;
	}
}

species patient skills:[moving]{ // #MG# 'Moving' skill should be removed because a patient cannot move by himself. 
	EmergencyCar rideEmergencyCar;
	EmergencyCar waitingAmbulance;
	bool inHospital;
	bool isTargeted;
	
	int timeAlive; 
	
	init{
		timeAlive <- 100 + rnd(20);
	}
	
	reflex dying{
		timeAlive <- timeAlive - 1;
		if(timeAlive<=30){ // #MG# This method doesn't work. it's may be because patient is drawn as a image file not a shape. 
			draw circle(20) color:#red;
		}
		if(timeAlive<=0){
			write self.name+" is dead"; // #MG# Where is the name set at the first time? But the auto-generated name is proper.
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
			do die; // #MG# Where is 'die' defined? is it a built-in action for species? => Yes, destroy the agent
		}
		
		// #MG# Assertion
		if(waitingAmbulance!=nil and waitingAmbulance.targetPatient!=self){
			write "[Error2]: "+self.name+" is waiting "+waitingAmbulance+", but it is not targeting this patient.";
		}
	}
	
	action recover {
		if (rideEmergencyCar is publicAmbulance){
			nb_patient_saved_by_ambulance <- nb_patient_saved_by_ambulance+1;
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

species EmergencyCar skills:[moving] { // #MG# to set the speed for cars
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
		if(location distance_to targetHospital.location < 3){ // #MG# '3'의 크기?? 환자 Pickup할 때는 등호였는데
			do releasePatient;
		}
	}
	
	action pickPatient{ // #MG# 환자 두명을 태우는 상황 발생...!!! => 이 아니라, 태우고 가던 중 환자가 죽는 경우- 가는 길에 있던 가까운 환자를 태우는 것
		ridePatient <- targetPatient;
		// #MG# distance on graph 로 가장 가까운 병원을 설정해야하는 것 아닌가.
		// #MG# closest_to 는 euclidean distance로 계산하는듯
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
	reflex setTarget when: targetPatient = nil and ridePatient = nil {
		do findTarget;
	}
	
	reflex moveToPatient when: targetPatient != nil and ridePatient = nil{
		do goto target:targetPatient.location on: road_network;//on: road_network;
		if (location = targetPatient.location) { // #MG# 왜 여기는 3이 아닌가?
			do pickPatient;
		}
	}
	
	action findTarget{
		if(targetPatient!=nil){
			write "[ERROR1] "+self.name+" has target patient, but it is trying to find target.";
		}
		
		// 기본 조건: 뭔가 타고 있지 않고, #MG# <나랑 위치가 같지 않음>???. 다른 ambulance 에 의해 target 되지 않음
		 
		// Policy 1 : 제일 가까운 patient 를 고름
		// #MG# The basis of distance calculation is not 'distance on graph', but following 'euclidean distance' btw the two
		// #MG# It is not realistic. closest_to 도 마찬가지인듯.
		// #MG# 그리고 현재 loop 구현 상태로는 같은 거리에 있는 patient들 중 하나만 고려대상이 됨
		// #MG# Shortest Path를 구하는 방법을 고려해야할듯 ref) http://gama-platform.org/tutorials#GraphSpecies
		// #MG# Graph Distance: https://groups.google.com/d/msg/gama-platform/1e5M3KTz2Ko/kvKoJcEJeqYJ
		// #MG# "using topology(the_graph)"
		loop d from:1 to:maxSearchDistance{
			patient candidate <- one_of (patient at_distance d);
			if (candidate!=nil and !candidate.inHospital and candidate.rideEmergencyCar=nil and !candidate.isTargeted){
				targetPatient <- candidate;
				write self.name+": patient "+candidate.name+" at distance of "+d+" will be saved by me";
				break;
			}
		}
		// Policy2: 환자가 생기는 순서대로 구하기
		// Policy3: 환자의 생명력이 짧은 순서대로 구하기
		// Policy4: 멀리 있는 환자부터 구하기
		// Policy5: 구할 수 있을 때만 구하기?
		
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
		
		// 근처에 환자가 있으면
		loop d from:1 to:privateCarSearchDistance{
			patient candidate <- one_of (patient at_distance d);
			if (candidate!=nil and !candidate.inHospital and candidate.rideEmergencyCar=nil and !candidate.isTargeted){
				targetPatient <- candidate;
				do pickPatient;
				write self.name+": patient "+candidate.name+" at distance of "+d+" will be saved by me";
				break;
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
    	display View1 type:opengl {
    	  	species road aspect:geom; // #MG# how about using 'default'
			species building aspect:geom;
			species patient;
    	  	species EmergencyCar;
    	  	species hospital;
    	  	species publicAmbulance;
    	  	species privateCar;
    	}
    	
    	display chart refresh: every(10) {
			chart "Disease spreading" type: series {
				data "patient made" value: nb_patient_made color: #black;
				data "patient saved by ambulance" value: nb_patient_saved_by_ambulance color: #blue;
				data "patient saved by car" value: nb_patient_saved_by_car color: #green;
				data "patient dead" value: nb_patient_dead color: #red;
			}
		}
  	}
}