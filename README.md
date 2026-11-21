# DeltaSuite — Project Delta

Script modular en Luau con interfaz táctica limpia para **Project Delta** (`PlaceId: 7336302630`), enfocado únicamente en **Combat**, **Visuals** y **Settings**.

## Ejecución rápida (Loadstring)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/DeltaSuite-ProjectDelta/main/DeltaSuite.luau"))()
```

O usando el cargador con manejo de errores (`loader.luau`):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/DeltaSuite-ProjectDelta/main/loader.luau"))()
```

## Módulos incluidos

- **Combat**
  - **Aimbot** (`Camera` / `Mouse` con suavizado y acumulador sub-píxel), **FOV Circle** (estático o dinámico con zoom), predicción balística basada en `MuzzleVelocity` y `ProjectileDrop` de `ReplicatedStorage.AmmoTypes`.
  - **Silent Aim** sobre `Bullet.CreateBullet` (`ReplicatedStorage.Modules.FPS.Bullet`) con Hit Chance, Wall Check, FOV, Team Check y target AI/Jugadores.
  - **Weapon Mods**: No Recoil (`RecoilPattern`, `VFX.RecoilCamera`, `SettingsModule` y `springs`), No Spread (`AccuracyDeviation`), No Sway, Fast ADS y Disable Scope DOF con restauración limpia.
  - **Hitbox Expander** (`FaceHitBox`, `HeadTopHitBox`, `Head`, `HumanoidRootPart`) con restauración automática de propiedades.
  - **TriggerBot** con retardo configurable y filtro ADS/Equipo/AI.
- **Visuals**
  - **Player ESP & AI ESP**: Cajas `Corner`/`2D`, nombre, barra y texto de vida, distancia, arma equipada, insignia `[DOWNED]`, esqueleto, tracers y Chams (`Highlight`).
  - **Loot, Corpses & Extractions**: Contenedores (`Workspace.Containers`) con filtro de vacíos y objetos de valor, ítems tirados (`Workspace.DroppedItems`) y extracciones (`Workspace.NoCollision.ExitLocations`).
  - **World & Vision**: Fullbright, Brightness/ClockTime, No Fog (`Atmosphere`), No Blur/DOF (`Lighting` PostEffects) y Custom FOV.
- **Settings**
  - Tecla de menú personalizable (`RightControl` por defecto), Watermark, Target Info HUD, notificaciones, restauración completa del entorno/armas/hitboxes y descarga limpia (`Unload Delta Suite`).
