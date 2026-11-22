# DeltaSuite — Project Delta

Script modular en Luau con interfaz táctica limpia para **Project Delta** (`PlaceId: 7336302630`), organizado en **Combat**, **Visuals**, **Misc** y **Settings**.

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
  - **Aimbot** (`Camera` / `Mouse` con suavizado y acumulador sub-píxel), **FOV Circle** (estático o dinámico con zoom), predicción balística basada en `MuzzleVelocity`, `ProjectileDrop` y `Drag` de `ReplicatedStorage.AmmoTypes`.
  - **Silent Aim** mejorado sobre `Bullet.CreateBullet` (`ReplicatedStorage.Modules.FPS.Bullet` con `hookfunction`/restauración limpia): convergencia sin paralaje al punto exacto, eliminación temporal de `AccuracyDeviation` en munición/arma/accesorios, **Target Priority** (`Crosshair` / `Closest Dist` / `Lowest HP`), **Multi-Point Scan** para bordes/head-glitches, compensación de caída gravitacional (-70 st/s^2 con arrastre), `Ignore Downed`, Wall Check, FOV, Team Check y **Show Target Line**.
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
- **Misc**
  - **Misc**: `Fast Trade` (desbloquea validación y botones `Confirm`/`Exchange`), `Panic Mode` (`End` por defecto, con popover `Panic Key` / `Hide Visuals` / `Disable Combat` / `Hide Menu`), `Pass Door` (traspasar puertas dentro de rango + popover `Pass Key` / `Mode` / `Phase Range` / `Auto Open Unlocked`), `Screen Effects` (oculta flashbang/ear-ringing/visor/daño manteniendo pantallas de muerte y miras), `Report Notify` (`UAC.Reports` y `ReportList.Recent`), y `Join Notify` (entradas/salidas con antigüedad y banderas).
  - **Detect**: detección automática de `Content Creator` (`[CC]`), `Tester` (`[TESTER]`), `Moderator` (`[MOD]`, rango grupo Project Delta + `ChatTags`) y `Cheater` (`[CHEATER]` por `TotalFlags` / `HSR` / `KDR`), con popover independiente para `Notify Alert`, `ESP Badge` y umbrales.
  - **Vault Sort**: botón `Sort By Value` para valorar `VaultStorage.Inventory` (incluidos rublos, objetos anidados y llaves) y ordenar ranuras por valor descendente.
- **Settings**
  - Tecla de menú personalizable (`RightControl` por defecto), Watermark, Target Info HUD, notificaciones, restauración completa del entorno/armas/puertas/efectos y descarga limpia (`Unload Delta Suite`).
