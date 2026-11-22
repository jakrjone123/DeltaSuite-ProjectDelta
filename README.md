# DeltaSuite — Project Delta

Script modular en Luau con interfaz táctica translúcida para **Project Delta** (`PlaceId: 7336302630`), organizado en **Combat**, **Visuals**, **World**, **Misc** y **Settings**.

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
  - **Aimbot** (`Camera` / `Mouse` con curva exponencial independiente de FPS, **Sticky Target**, **Target Priority**, **Multi-Point Scan**, **Visible Fallback**, **Lock Behind Walls** para fijar objetivos detrás de estructuras, **Only When ADS**), **FOV Circle** (estático o dinámico con zoom), predicción balística con suavizado de velocidad EMA desde `Delta.GetShotOrigin()` (`MuzzleVelocity`, `ProjectileDrop`, `Drag`) y **`Add Not Attack`**.
  - **Silent Aim** mejorado sobre `Bullet.CreateBullet` (`ReplicatedStorage.Modules.FPS.Bullet` con `hookfunction`/restauración limpia): convergencia sin paralaje al punto exacto, eliminación temporal de `AccuracyDeviation` en munición/arma/accesorios, **Target Priority** (`Crosshair` / `Closest Dist` / `Lowest HP`), **Multi-Point Scan** para bordes/head-glitches, compensación de caída gravitacional (-70 st/s^2 con arrastre), `Ignore Downed`, Wall Check, FOV, Team Check, **Show Target Line** y **`Add Not Attack`**.
  - **Targeting** (asistente de Silent Aim): `FOV`, `Dynamic FOV`, `Aim Point` (`Selected` / `Closest` / `Random`), `Aim Parts` multi-selección (`Head`, `FaceHitBox`, `HeadTopHitBox`, `UpperTorso`, etc.), `Visible Fallback`, `Wallbang` configurable (muros máximos, grosor y `NoPen`), **`Add Not Attack`** (tecla configurable para marcar a cualquier jugador como aliado/no atacar aunque no esté en tu team/clan, con badge `[FRIEND]` en ESP y botón `Clear Not Attack List`) y `Raycast Budget`.
  - **Weapon Mods**: No Recoil (`RecoilPattern`, `VFX.RecoilCamera`, `SettingsModule` y `springs`), No Spread (`AccuracyDeviation`), No Sway, Fast ADS y Disable Scope DOF con restauración limpia.
  - **TriggerBot** verificado con resolución de modelos anidados (cascos, chalecos, mochilas y accesorios sobre `Actors`), canal `WeaponRay` con paso por vidrio/`PassThrough`, filtro de hitbox (`Any` / `Head Only` / `Body Only`), distancia máxima configurable, `Ignore Downed`, retardo proporcional sin solapamiento y protección de menú/escritura.
- **Visuals (ESP por categoría con panel de filtros)**
  - **Player**: `Highlights`, `Box`, `Name`, `HealthBar`, `Health`, `Distance`, `KDR` (calculado desde `Status.Journey.Statistics`, igual que `ReportGui`), `Check Reports` (severidad visual por colores `Rep` / `[!] REP` / `[BANNING]`), `Tracers`, `Arrows` (fuera de pantalla), `Skeleton`, `Held Weapon`, `Downed Badge`, filtros de escuadra y colores.
  - **Npc**: `Highlight`, `Box`, `Name`, `HealthBar`, `Health`, `Distance`, `Tracers`, `Arrows`, `Skeleton`, `Held Weapon`, colores NPC/Boss.
  - **Corpse**: `Chams`, `Box`, `Name`, `Distance`, `Value`, `Tracers`, `Arrows`, `Skeleton`, ocultar vacíos.
  - **Container**: `Chams`, `Box`, `Name`, `Distance`, `Value`, `Respawn`, `Tracers`, `Arrows`, ocultar vacíos y filtro por valor mínimo.
  - **Dropped Item**: `Chams`, `Box`, `Name`, `Distance`, `Value`, `Tracers`, `Arrows`, filtro por valor mínimo.
  - **Quest Items**: `Chams`, `Box`, `Name`, `Distance`, `Tracers`, `Arrows`.
  - **PREVIEW interactivo en las 6 categorías ESP**:
    - **Player y Npc**: Muñeco 3D obsidiana minimalista con iniciales **`DS`** iluminadas en el pecho sobre pedestal octogonal 3D con halo radial y proyección exacta de esqueleto en tiempo real; permite arrastrar y apilar etiquetas (`Name`, `Health`, `Distance`, `Weapon`, `KDR`, `Reports`, `Downed`) y la barra `HealthBar` exclusivamente entre **Arriba**, **Abajo**, **Izquierda** y **Derecha**.
    - **Corpse, Container, Dropped Item y Quest Items**: Cubo 3D táctico lateral con soporte en vivo de `Chams`, `Box`/`Corner` con relleno translúcido, `Skeleton` (Corpse), `Tracers`, `Arrows` y arrastre ordenado de etiquetas (`Name`, `Distance`, `Value`, `Respawn`) entre las 4 zonas.
  - **World & Vision**: Ajustes rápidos de iluminación y visión.
- **World**
  - **World**: `Terrain Colors` (presets `Default` / `Cyber` / `Arctic` / `Mars` / `Custom` y colores por material), `Leaves` y `Tree Trunks` (tinte de malla/`SurfaceAppearance`, transparencia y ocultación), `Water Color`, `No Grass` (`Terrain.Decoration`) y `No Mines` (desactivación segura de `PMN2`/`MON50`/minas y prompts).
  - **Features**: `Render Players`, `Boss Checker` (detección de bosses/eventos en vivo con alertas y barra HUD), `ExitLocations` (distancia, color, temporizador y tracers) y `Radar` táctico 2D rotatorio en tiempo real (jugadores, NPC/Boss, cadáveres y extracciones).
  - **Lighting**: 10 controles modulares con popovers independientes (`Light`, `Time & Sun`, `Shadows`, `Rendering`, `Fog`, `Atmosphere`, `Sky`, `Clouds`, `Bloom` y `Blur`) con respaldo y restauración completa.
- **Misc**
  - **Misc**: `Fast Trade` (desbloquea validación y botones `Confirm`/`Exchange`), `Panic Mode` (`End` por defecto, con popover `Panic Key` / `Hide Visuals` / `Disable Combat` / `Hide Menu`), `Pass Door` (traspasar puertas dentro de rango + popover `Pass Key` / `Mode` / `Phase Range` / `Auto Open Unlocked`), `Screen Effects` (oculta flashbang/ear-ringing/visor/daño manteniendo pantallas de muerte y miras), `Report Notify` (alertas UAC en vivo con estabilización tras replicación para evitar falsos positivos), y `Join Notify` (entradas/salidas con antigüedad y banderas).
  - **Detect**: detección automática de `Content Creator` (`[CC]`), `Tester` (`[TESTER]`), `Moderator` (`[MOD]`, rango grupo Project Delta + `ChatTags`) y `Cheater` (`[CHEATER]` por `TotalFlags` / `HSR` / `KDR`), con popover independiente para `Notify Alert`, `ESP Badge` y umbrales.
  - **Check Reports**: escáner en vivo y HUD flotante arrastrable (`Reports HUD` + `Scan Server Reports`) ordenado por reportes totales en la partida, con filtro `Flagged` / `All`, KDR y distancia.
  - **Vault Sort**: botón `Sort By Value` para valorar `VaultStorage.Inventory` (incluidos rublos, objetos anidados y llaves) y ordenar ranuras por valor descendente.
- **Settings**
  - **Config Manager**: guardado, carga, listado dinámico de perfiles en disco (`DeltaSuite/configs/*.json` con respaldo en memoria), `Auto Load Selected` (`DeltaSuite/autoload.txt`) y eliminación segura (serializando colores `Color3`, keybinds `EnumItem`, layouts y filtros).
  - Interfaz táctica translúcida con control deslizante `Menu Transparency` (`0..45%`), tecla de menú personalizable (`RightControl`), Watermark, Target Info HUD, notificaciones, restauración completa del entorno/armas/puertas/efectos y descarga limpia (`Unload Delta Suite`).
