
#nullable enable

using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
using YamlDotNet.Serialization;

namespace Configurator.Models
{
    // Classes for parsing DSC YAML configuration files

    public class DscConfiguration
    {
        [YamlMember(Alias = "$schema", ApplyNamingConventions = false)]
        public string? Schema { get; set; }

        [YamlMember(Alias = "resources")]
        public List<DscResourceInput> Resources { get; set; } = new();
    }

    public class DscResourceInput
    {
        [YamlMember(Alias = "name")]
        public string Name { get; set; } = "";

        [YamlMember(Alias = "type")]
        public string Type { get; set; } = "";

        [YamlMember(Alias = "properties")]
        public object? Properties { get; set; }

        public string ToJson()
        {
            // Serialize the entire DscResourceInput object to JSON
            // This will include Name, Type, and Properties
            return JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = false });
        }
    }


    // Classes for parsing the JSON output of the 'dsc' command

    public class DscOutput
    {
        [JsonPropertyName("results")]
        public List<DscResult> Results { get; set; } = new();
    }

    public class DscResult
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("type")]
        public string Type { get; set; } = "";

        [JsonPropertyName("result")]
        public DscResultPayload Result { get; set; } = new();
    }

    public class DscResultPayload
    {
        [JsonPropertyName("inDesiredState")]
        public bool? InDesiredState { get; set; }

        [JsonPropertyName("changedProperties")]
        public List<object>? ChangedProperties { get; set; }

        [JsonPropertyName("beforeState")]
        public JsonElement? BeforeState { get; set; }

        [JsonPropertyName("afterState")]
        public JsonElement? AfterState { get; set; }

        [JsonPropertyName("desiredState")]
        public JsonElement? DesiredState { get; set; }

        [JsonPropertyName("actualState")]
        public JsonElement? ActualState { get; set; }

        [JsonPropertyName("differingProperties")]
        public List<string>? DifferingProperties { get; set; }
    }
}
