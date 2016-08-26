/**
* Name: SoS
* Author: Jihun
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model SoS

global{
//	float step <- 1 #minutes;
	
	int nPatient<-20;
	int nAmbulance<-10;
	int nHospital<-5;
	
	int maxSearchDistance <- 2000;
	
	string patientFile const: true <- '../images/patient.jpg' ;
	string ambulanceFile const: true <- '../images/ambulance.png' ;
	string hospitalFile const: true <- '../images/hospital.png' ;
	
	file roads_shapefile <- file("../includes/road.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	geometry shape <- envelope(roads_shapefile);
	graph road_network;
	
	float ambulanceSpeed <- 50 #km / #h;
	float makePatientProbability <- 0.1;
	
	int nb_patient_made <- nPatient;
	int nb_patient_saved <- 0;
	int nb_patient_dead <- 0;
	
	init {
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		
		create building from: buildings_shapefile; 
		
    	create patient number: nPatient { 
//    	  location <- {rnd(100), rnd(100)};
			building bd <- one_of(building);
			location <- any_location_in(bd);       
    	} 
    	create hospital number: nHospital { 
    	  building bd <- one_of(building);
			location <- any_location_in(bd);          
    	}
    	create ambulance number: nAmbulance {
    		speed <- ambulanceSpeed; 
    	  hospital bd <- one_of(hospital);
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
	ambulance rideAmbulance;
	ambulance waitingAmbulance;
	bool inHospital;
	bool isTargeted;
	
	int timeAlive;
	
	init{
		timeAlive <- 100 + rnd(20);
	}
	
	reflex waitingAmbulance{
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
			if(rideAmbulance!=nil){
				ask rideAmbulance{
					targetPatient<-nil;
					ridePatient<-nil;
				}
			}
			do die;
		}
		
		if(waitingAmbulance!=nil and waitingAmbulance.targetPatient!=self){
			write "[Error2]: "+self.name+" is waiting "+waitingAmbulance+", but it is not targeting this patient.";
		}
	}
	
	action recover {
		nb_patient_saved <- nb_patient_saved+1;
		
		inHospital<-true;
		rideAmbulance<-nil;
		waitingAmbulance<-nil;
		isTargeted<-false;
		
		do die;
	}
	
	aspect default{
		draw  file(patientFile) rotate: heading at: location size: {15,15} ;
	}
}

species ambulance skills:[moving] {
	patient targetPatient;
	patient ridePatient;
	hospital targetHospital;
	
	reflex setTarget when: targetPatient = nil and ridePatient = nil {
		do findTarget;
	}
	
	reflex moveToPatient when: targetPatient != nil and ridePatient = nil{
		do goto target:targetPatient.location on: road_network;//on: road_network;
		if (location = targetPatient.location) {
			do pickPatient;
		}
	}
	
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
	
	action findTarget{
		if(targetPatient!=nil){
			write "[ERROR1] "+self.name+" has target patient, but it is trying to find target.";
		}
		
		// 뭔가 타고 있지 않고, 나랑 위치가 같지 않은 것중에 제일 가까운 patient 를 골라야 함
		loop d from:1 to:maxSearchDistance{
			patient candidate <- one_of (patient at_distance d);
			if (candidate!=nil and !candidate.inHospital and candidate.rideAmbulance=nil and !candidate.isTargeted){
				targetPatient <- candidate;
				write self.name+": patient "+candidate.name+" at distance of "+d+" will be saved by me";
				break;
			}
		}
		
		if(targetPatient!=nil){
			ask targetPatient{
				isTargeted <- true;
				waitingAmbulance <- myself;
			}
		}
	}
	
	action pickPatient{
		ridePatient <- targetPatient;
		targetHospital <- hospital closest_to(self); // 환자에게 가장 가까운 병원으로 목적지 설정
		ask ridePatient{
			rideAmbulance <- myself;
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
		draw file(ambulanceFile) size:{20,20};
	}
}



experiment exp1 type:gui{
	parameter "Initial number of patients: " var: nPatient min: 1 max: 1000 category: "Patients" ;	
  	output {
    	display View1 type:opengl {
    	  	species road aspect:geom;
			species building aspect:geom;
			species patient;
    	  	species ambulance;
    	  	species hospital;
    	}
    	
    	display chart refresh: every(10) {
			chart "Disease spreading" type: series {
				data "patient made" value: nb_patient_made color: #black;
				data "patient saved" value: nb_patient_saved color: #blue;
				data "patient dead" value: nb_patient_dead color: #red;
			}
		}
  	}
}