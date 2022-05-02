#include <sdkhooks>
#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

int maxAmmo = 1;
int maxClip = 3;

//Offsets
int m_iPrimaryAmmoType;
int m_iAmmo;

public void OnPluginStart(){
    m_iPrimaryAmmoType = FindSendPropInfo("CBaseCombatWeapon", "m_iPrimaryAmmoType");
    m_iAmmo = FindSendPropInfo("CBasePlayer", "m_iAmmo");
}

public void OnEntityCreated(int entity, const char[] className){
    if(!IsValidEntity(entity)) return;
    if(StrContains(className,"weapon_") == -1) return;//Obviamente solo queremos armas...
    if(StrContains(className,"flash") != -1 || StrContains(className,"grenade") != -1 || StrContains(className,"c4") != -1 || StrContains(className,"knife") != -1) return;//Y obviamente solo armas que no sean utilidades o la C4
    if(StrContains(className,"m4a1") == -1) return;

    CreateTimer(0.5,SetWeaponAmmo,entity);
    SDKHook(entity, SDKHook_Reload, Hook_WeaponReloadPost);
}

public Action SetWeaponAmmo(Handle timer, int entity){
    if(!IsValidEntity(entity) || !HasEntProp(entity,Prop_Data,"m_iClip1")) return Plugin_Stop;
    //Set Max secondary clip and max clip
    SetEntProp(entity,Prop_Data,"m_iClip1",maxAmmo);
    SetSecondaryAmmo(entity,maxClip);
    return Plugin_Stop;
}

public Action Hook_WeaponReloadPost(int weapon)
{
    char className[64];
    GetEntityClassname(weapon,className,sizeof(className));
    int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(!IsValidEntity(owner) || !IsClientInGame(owner)) return Plugin_Continue;//El arma debe tener alguien que la este utilizando...
    int currentAmmo = GetCurrentAmmo(weapon);
    if(currentAmmo >= maxAmmo) return Plugin_Handled;
    int currentReserve = GetCurrentReserve(weapon);
    if(currentReserve == 0) return Plugin_Handled;

    DataPack pack = new DataPack();

    CreateTimer(0.1,WeaponReload,pack, TIMER_REPEAT);
    pack.WriteCell(weapon);
    pack.WriteCell(currentAmmo);
    pack.WriteCell(currentReserve);
    return Plugin_Changed;
}

public Action WeaponReload(Handle timer, DataPack pack){
    pack.Reset();
    int weapon = pack.ReadCell();
    int oldAmmo = pack.ReadCell();
    int oldReserve = pack.ReadCell();
    
    if(!HasEntProp(weapon,Prop_Data,"m_iState")) return Plugin_Stop; //Todas las armas tienen el m_iState...
    int state = GetEntProp(weapon,Prop_Data,"m_iState");
    if(state != 2) return Plugin_Stop;//El estado 2 es que actualmente el arma esta activa como principal en algún cliente. (No dropeada o en la espalda de algún jugador)
    char classname[32]; 
    GetEntityClassname(weapon, classname, sizeof(classname));
    int currentAmmo = GetCurrentAmmo(weapon);
    if(currentAmmo == oldAmmo) return Plugin_Continue;//La recarga aún no a finalizado..

    // La recarga finalizo, debemos colocar los nuevos valores
    int newReserve = oldReserve-maxAmmo;
    SetEntProp(weapon,Prop_Data,"m_iClip1", maxAmmo);
    SetSecondaryAmmo(weapon,newReserve);
    return Plugin_Stop;
}

// Obtiene la cantidad de munición actual
int GetCurrentAmmo(int weapon){
    if(!IsValidEntity(weapon)) return 0;
    if(!HasEntProp(weapon,Prop_Data,"m_iClip1")) return 0;
    return GetEntProp(weapon,Prop_Data,"m_iClip1");
}

// Obtiene la cantidad de munición en reserva actual
int GetCurrentReserve(int weapon){
    if(!IsValidEntity(weapon)) return 0;
    int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(!IsValidEntity(owner) || !IsClientInGame(owner)) return 0;

    int WeaponID = GetEntData(weapon, m_iPrimaryAmmoType) * 4;
    return GetEntData(owner, m_iAmmo + WeaponID);
}

// Coloca una cantidad indicada en la reserva del arma
void SetSecondaryAmmo(int weapon, int amount){
    if(!IsValidEntity(weapon)) return;
    int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(!IsValidEntity(owner) || !IsClientInGame(owner)) return;

    int WeaponID = GetEntData(weapon, m_iPrimaryAmmoType) * 4;
    SetEntData(owner, m_iAmmo + WeaponID, amount);
}