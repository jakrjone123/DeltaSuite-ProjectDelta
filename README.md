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
  - **Targeting** (asistente de Silent Aim): `FOV`, `Dynamic FOV`, `Aim Point` (`Selected` / `Closest` / `Random`), `Aim Parts` multi-selección (`Head`, `FaceHitBox`, `HeadTopHitBox`, `UpperTorso`, etc.), `Visible Fallback`, `Target AI`, `Wallbang` configurable (muros máximos, grosor y `NoPen`), `Add Friend` (`MB3` whitelist) y `Raycast Budget`.
  - **Weapon Mods**: No Recoil (`RecoilPattern`, `VFX.RecoilCamera`, `SettingsModule` y `springs`), No Spread (`AccuracyDeviation`), No Sway, Fast ADS y Disable Scope DOF con restauración limpia.
  - **TriggerBot** con retardo configurable y filtro ADS/Equipo/AI.
- **Visuals (ESP por categoría con panel de filtros)**
  - **Player**: `Highlights`, `Box`, `Name`, `HealthBar`, `Health`, `Distance`, `KDR`, `Reports`, `Tracers`, `Arrows` (fuera de pantalla), `Skeleton`, `Held Weapon`, `Downed Badge`, filtros de escuadra y colores.
  - **Npc**: `Highlight`, `Box`, `Name`, `HealthBar`, `Health`, `Distance`, `Tracers`, `Arrows`, `Skeleton`, `Held Weapon`, colores NPC/Boss.
  - **Corpse**: `Chams`, `Box`, `Name`, `Distance`, `Value`, `Tracers`, `Arrows`, `Skeleton`, ocultar vacíos.
  - **Container**: `Chams`, `Box`, `Name`, `Distance`, `Value`, `Respawn`, `Tracers`, `Arrows`, ocultar vacíos y filtro por valor mínimo.
  - **Dropped Item**: `Chams`, `Box`, `Name`, `Distance`, `Value`, `Tracers`, `Arrows`, filtro por valor mínimo.
  - **Quest Items**: `Chams`, `Box`, `Name`, `Distance`, `Tracers`, `Arrows`.
  - **PREVIEW interactivo en las 6 categorías ESP**:
    - **Player y Npc**: Muñeco 3D lateral con overlays en tiempo real; permite arrastrar y apilar etiquetas (`Name`, `Health`, `Distance`, `Weapon`, `KDR`, `Reports`, `Downed`) y la barra `HealthBar` exclusivamente entre **Arriba**, **Abajo**, **Izquierda** y **Derecha**.
    - **Corpse, Container, Dropped Item y Quest Items**: Cubo 3D táctico lateral con soporte en vivo de `Chams`, `Box`/`Corner` con relleno translúcido, `Skeleton` (Corpse), `Tracers`, `Arrows` y arrastre ordenado de etiquetas (`Name`, `Distance`, `Value`, `Respawn`) entre las 4 zonas.
  - **Extractions & World**: Ubicaciones de extracción (`ExitLocations`), Fullbright, Brightness/ClockTime, No Fog (`Atmosphere`), No Blur/DOF (`Lighting` PostEffects) y Custom FOV.
- **Settings**
  - Tecla de menú personalizable (`RightControl` por defecto), Watermark, Target Info HUD, notificaciones, restauración completa del entorno/armas y descarga limpia (`Unload Delta Suite`).
