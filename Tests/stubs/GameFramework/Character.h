#pragma once
struct ACharacter {bool local=true,player=true; bool IsLocallyControlled()const{return local;} bool IsPlayerControlled()const{return player;}};