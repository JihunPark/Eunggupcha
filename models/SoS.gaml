/**
* Name: SoS
* Author: Jihun
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model SoS

global{
	int nPatient<-200;
	int nAmbulance<-10;
	int nHospital<-5;
	
	int maxSearchDistance <- 100;
	
	string patientFile const: true <- '../images/patient.jpg' ;
	string ambulanceFile const: true <- '../images/ambulance.png' ;
	string hospitalFile const: true <- '../images/hospital.png' ;
	
	init { 
    create patient number: nPatient { 
      location <- {rnd(100), rnd(100)};       
    } 
    create ambulance number: nAmbulance { 
      location <- {rnd(100), rnd(100)};       
    }
    create hospital number: nHospital { 
      location <- {rnd(100), rnd(100)};       
    }  
  } 
}

species hospital{
	aspect default{
		draw  file(hospitalFile) size: {7,5} ;
	}
}

species patient skills:[moving]{
	ambulance rideAmbulance;
	bool inHospital;
	bool isTargeted;
	
	aspect default{
		draw  file(patientFile) rotate: heading at: location size: {3,3} ;
	}
}

species ambulance skills:[moving] control:fsm{
	patient targetPatient;
	patient ridePatient;
	hospital targetHospital;
	
	action pickPatient{
		ridePatient <- targetPatient;
		targetHospital <- hospital closest_to(self); // 가장 가까운 병원으로 목적지 설정
		ask ridePatient{
			rideAmbulance <- myself;
		}
		targetPatient <- nil;
		
		write self.name+": I just pick patient "+ridePatient.name+" and this patient will be delivered to "+targetHospital.name;
	}
	
	action releasePatient{
		ask ridePatient{
			inHospital<-true;
			rideAmbulance<-nil;
		}
		
		write self.name+": "+ridePatient.name+" is delivered to "+targetHospital.name+".";
		
		ridePatient <- nil;
		targetHospital<-nil;
	}
	
	action findTarget{
		// 뭔가 타고 있지 않고, 나랑 위치가 같지 않은 것중에 제일 가까운 patient 를 골라야 함
//		targetPatient <- patient closest_to(self);
		loop d from:2 to:maxSearchDistance{
			patient candidate <- one_of (patient at_distance d);
			if (candidate!=nil and !candidate.inHospital and candidate.rideAmbulance=nil and !candidate.isTargeted){
				targetPatient <- candidate;
				write self.name+": patient "+candidate.name+" at distance of "+d+" will be saved by me";
				break;
			}
		}
		if(targetPatient=nil){
			write self.name+": there is no patient in "+maxSearchDistance;
		}else{
			ask targetPatient{
				isTargeted <- true;
			}
		}
	}
	
	reflex staying when: targetPatient = nil and ridePatient = nil {
//		write "stay!";
		do findTarget;
	}
	
	reflex move when: targetPatient != nil and ridePatient = nil{
//		write "move!";
		do goto target:targetPatient.location ;//on: road_network;
		if (location = targetPatient.location) {
			do pickPatient;
		}
	}
	
	reflex movePatient when: ridePatient!=nil{
//		write "movePatient!";
		do goto target:targetHospital.location;
		
		ask ridePatient{
			location <- myself.location;
		}
		
		if(location = targetHospital.location){
			do releasePatient;
		}
	}
			
	aspect default{
		draw file(ambulanceFile) size:{5,5};
//		draw circle(maxSearchDistance);
	}
}



experiment exp1 type:gui{
	parameter "Initial number of patients: " var: nPatient min: 1 max: 1000 category: "Patients" ;	
  	output {
    	display View1 type:opengl {
    	  	species patient;
    	  	species ambulance;
    	  	species hospital;
    	}
  	}
}