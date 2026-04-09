# Field Diagnostics — Structured Troubleshooting

## Purpose — The Diagnostic Interview

Before jumping to solutions, this skill guides you through structured questioning to identify the actual problem. Misdiagnosis wastes time and parts. A 5-minute diagnostic interview saves hours of wrong-path repairs.

**RULE: Diagnose first, fix second. Never replace parts based on a guess.**

## The Diagnostic Framework

Every problem on a boat follows this sequence:

```
OBSERVE → ISOLATE → TEST → DIAGNOSE → VERIFY → FIX
```

### 1. OBSERVE — What exactly is happening?
### 2. ISOLATE — What system is affected?
### 3. TEST — What can we measure or check?
### 4. DIAGNOSE — What's the most likely cause?
### 5. VERIFY — Does our diagnosis match the evidence?
### 6. FIX — Address the root cause, not just the symptom

## System Identification — What Broke?

### Engine Won't Start — Decision Tree

**Does the starter turn?**
- **NO** → Electrical problem (battery, switch, starter, wiring)
  - Check battery voltage: above 12.4V?
    - **NO** → Dead/discharged battery. Charge or jump.
    - **YES** → Check battery terminals (corroded?), battery switch (correct position?), starter solenoid (clicking?), starter motor connections
- **YES, cranks normally** → Fuel or compression problem
  - Fuel in the tank? (verify, don't assume)
    - **YES** → Is fuel getting to the engine?
      - Check: fuel shutoff valve open? Primary filter bowl has fuel? Bleed the system.
      - After bleeding, still won't start? → Check glow plugs (diesel) or spark (gas)
    - **NO** → Add fuel. Bleed the system.
- **YES, cranks slowly** → Weak battery or starter problem
  - Check battery voltage while cranking: drops below 10V?
    - **YES** → Battery is weak. Charge or replace.
    - **NO** → Starter motor may be failing (draws too much current)

### Engine Overheating — Decision Tree

**Is water coming from the exhaust?**
- **NO** → Raw water flow problem
  - Seacock open? → Check
  - Strainer clogged? → Clean
  - Impeller failed? → Inspect/replace (most common cause)
  - Raw water hose collapsed? → Replace
- **YES, water flowing** → Heat exchange problem
  - Coolant level OK? (wait for engine to cool before checking)
    - **LOW** → Refill, check for leaks, look for blown head gasket (oil milky?)
    - **OK** → Thermostat stuck closed? (remove and test in hot water)
    - **OK** → Heat exchanger plugged? (may need professional cleaning)
    - **OK** → Exhaust mixing elbow restricted? (check for carbon buildup)

### No Electrical Power — Decision Tree

**Are any circuits working?**
- **NOTHING works** → Main battery disconnect
  - Battery switch in correct position?
  - Battery terminal connections tight and clean?
  - Main fuse/breaker tripped?
  - Battery voltage? (check at terminals with multimeter)
- **SOME circuits work** → Individual circuit problem
  - Which circuits are dead?
  - Check the fuses/breakers for those circuits
  - Check for tripped GFCI (shore power circuits)
  - Use voltage drop test to find the bad connection

### Water Ingress — Decision Tree

**Where is the water?**
- **Engine compartment/bilge** →
  - Is it seawater (salty) or freshwater (coolant/rain)?
    - **Seawater** → Check: stuffing box/shaft seal, exhaust hose connections, through-hull hoses, keel bolts
    - **Freshwater** → Check: cooling system leak, deck drain hose, window/hatch leak, condensation
  - Rate of ingress?
    - **Slow drip** → Find source, monitor, repair at convenience
    - **Steady stream** → Find and stop immediately. Close seacocks systematically to isolate.
    - **Flooding** → All pumps on, close all seacocks, identify breach, emergency repair, call for help
- **Under berths/lockers** → Often deck leaks through hardware fastener holes
- **Locker under cockpit** → Cockpit drain hose, steering system, lazarette hatch seal

## The Five Senses Diagnostic

Use your senses systematically:

### LOOK
- Fluid on surfaces (oil = dark/slick, coolant = green/pink, fuel = clear/amber, seawater = clear with salt residue)
- Discoloration (heat damage = brown/black, corrosion = green/white, rust = orange)
- Movement where there shouldn't be (loose fittings, vibrating components)
- Smoke or steam

### LISTEN
- Squealing = slipping belt
- Grinding = worn bearings, damaged gears
- Knocking = loose component, detonation, worn bearing
- Hissing = air/water leak under pressure
- Clicking = electrical relay, failed starter solenoid
- Silence where there should be sound = dead component

### SMELL
- Burning rubber = slipping belt, overheated wiring
- Diesel fuel = fuel leak (find it immediately)
- Hot metal = overheating, friction
- Rotten eggs = overcharged battery (hydrogen sulfide — ventilate!)
- Vinegar/acidic = osmotic blister fluid
- Sweet = antifreeze/coolant leak
- Sewage = head system leak or permeated hoses

### TOUCH (with engine OFF)
- Temperature differences along a component = blockage or flow problem
- Vibration = imbalance, loose mounting, worn bearing
- Wet surfaces = leak source
- Sticky residue = fuel or oil seep

### TASTE
- **Only for water identification**: touch a drop to your tongue
- Salty = seawater intrusion
- Sweet = coolant (CAUTION: antifreeze is toxic — spit and rinse)
- Neutral = rainwater/condensation

## Structured Questions for Any Problem

When someone reports a problem, ask these in order:

### 1. What Changed?
"When did this start? What were you doing when it happened?"
- Problems that appear suddenly have different causes than gradual ones
- Something changed — find what changed

### 2. What Did You Do Last?
"Did you do any recent maintenance? Change anything? Add anything?"
- Many problems are caused by the last person who worked on the system
- Filter change → air in fuel → won't start
- New battery → wrong terminals → electrical damage

### 3. Is It Consistent or Intermittent?
- **Consistent** = clear failure point. Easier to diagnose.
- **Intermittent** = loose connection, thermal sensitivity, or marginal component. Harder — test under conditions that trigger the failure.

### 4. What Makes It Better or Worse?
- "Does it get worse at high RPM?" → Load-related
- "Does it get worse when wet?" → Moisture/corrosion
- "Does it go away when it warms up?" → Thermal expansion, viscosity
- "Only happens at night?" → Electrical load from lights/instruments

### 5. What Have You Already Tried?
- Avoid re-doing what someone already checked
- But verify their work — "I checked the fuse" may mean they looked at it, not tested it with a multimeter

## Diagnostic Tools and How to Use Them

### Multimeter (Essential)
- **DC Voltage:** Battery state, circuit verification, alternator output
- **AC Voltage:** Shore power, inverter output
- **Resistance/Continuity:** Wire integrity, switch function, fuse testing
- **Voltage drop:** Finding bad connections (the most powerful technique)

### Infrared Thermometer (Very Useful)
- Check exhaust temperature (one cylinder hotter = injector problem)
- Find heat exchanger blockages (temperature gradient)
- Check electrical connections (hot = high resistance = bad connection)
- Verify thermostat operation

### Test Light / Circuit Tester
- Quick check for voltage presence
- Simpler than a multimeter for go/no-go testing
- Useful for tracing wiring

### Compression Tester
- Reveals cylinder condition (rings, valves, head gasket)
- All cylinders should read within 10% of each other
- Low across all cylinders = worn engine
- One cylinder low = valve or ring problem on that cylinder

## Common Misdiagnoses to Avoid

| Symptom | Common Wrong Diagnosis | Actual Cause |
|---------|----------------------|--------------|
| Engine won't start | Bad starter | Dead battery / corroded terminals |
| Engine overheating | Thermostat | Failed impeller |
| Battery dies overnight | Bad battery | Parasitic draw from a device left on |
| Bilge pump runs constantly | Leak in the hull | Stuffing box drip (normal) or dripless seal failure |
| Engine runs rough | Bad fuel | Air leak in fuel supply line |
| No charging | Alternator failure | Loose or glazed belt |
| Lights dim | Weak battery | Corroded ground connection |
| Head won't pump | Broken pump | Calcium buildup in discharge hose |

## Documenting Your Diagnosis

Log every diagnostic session:

```
Date: _______________
System: _______________
Symptom reported: _______________
Conditions when symptom occurs: _______________
Tests performed:
  1. _______________  Result: _______________
  2. _______________  Result: _______________
  3. _______________  Result: _______________
Diagnosis: _______________
Repair performed: _______________
Parts used: _______________
Verified fix: Yes / No
Notes for next time: _______________
```
