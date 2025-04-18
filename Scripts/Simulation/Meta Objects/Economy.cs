using Godot;
using Godot.Collections;
using System;
using System.Linq;

public partial class Economy : GodotObject
{
    public Dictionary<SimResource, double> resources = new Dictionary<SimResource, double>();
    
    public double ChangeResourceAmount(SimResource resource, double amount){
        if (amount > 0){
            if (!resources.ContainsKey(resource)){
                resources.Add(resource, amount);
            } else {
                resources[resource] += amount;
            }            
        } else if (resources.ContainsKey(resource)){
            resources[resource] += amount;
            if (resources[resource] <= 0){
                double extra = resources[resource];
                resources.Remove(resource);                
                return Mathf.Abs(extra);
            }
        }
        return 0;
    }

    public void SetResourceAmount(SimResource resource, double amount){
        if (amount > 0){
            if (!resources.ContainsKey(resource)){
                resources.Add(resource, amount);
            } else {
                resources[resource] = amount;
            }                
        } else if (resources.ContainsKey(resource)){
            resources.Remove(resource);
        }
    }

    public double AmountOfType(ResourceType type){
        double totalAmount = 0;
        foreach (var pair in resources.ToArray()){
            SimResource resource = pair.Key;
            if (resource != null && resource.types.Contains(type)){
                totalAmount += pair.Value;                
            }
        }
        return totalAmount;
    }

    public double AmountOfResource(SimResource resource){
        return resources[resource];
    }
}
