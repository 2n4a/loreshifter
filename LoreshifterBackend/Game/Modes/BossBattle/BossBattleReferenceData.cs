using System.Collections.Generic;
using Loreshifter.Game.Sessions;

namespace Loreshifter.Game.Modes.BossBattle;

public static class BossBattleReferenceData
{
    public static WorldDescription WorldLore { get; } = new()
    {
        Overview = "��� ��������� ���������� ����� ���������� ���������, ��� ������-������ �������� ����� �� ����������� ����.",
        Geography = "�������� ���� ����� � ������, ������������ �������� ������� ������, ��������� ��������� � ����� � ������� �������� ������ �����.",
        MagicSystem = "����� �������� �� �������� ����. �� ������� ��������� ����������, �� ����������� ������� �������� ��������� ����������.",
        Culture = "������ ������� � ������� ��������� ����������� �� �������� ��� ���������, � ��������� ����� ���������� �������� ��� ������ ��������� � ���������."
    };

    public static CharacterCreationRules CharacterRules { get; } = new()
    {
        Attributes = new List<CharacterAttributeDefinition>
        {
            new()
            {
                Id = "vitality",
                Name = "��������",
                Description = "���������� ����� ��������� ��� � ������������ � �����. ������� 3 ���� ��� ������� � �����.",
                MinValue = 3,
                MaxValue = 7
            },
            new()
            {
                Id = "might",
                Name = "����",
                Description = "�������� �� ���������� ����, �������� ������� �������� ��� � ������ � ������ �����������.",
                MinValue = 0,
                MaxValue = 7
            },
            new()
            {
                Id = "arcana",
                Name = "�����",
                Description = "������ �� �������� ������� �������, �������� ���������� � ������������ � ���������� �����.",
                MinValue = 0,
                MaxValue = 7
            },
            new()
            {
                Id = "aid",
                Name = "�������",
                Description = "���������� ������������� ����������� ������, ������� � ������ ��������������� ���������.",
                MinValue = 0,
                MaxValue = 7
            }
        },
        TotalAssignablePoints = 12,
        Guidance = "������������ ���� ����� ����������������. ���� �������� ������ ��������� 5 � ����, �� ��������� ���������� ���������������, ��������� � ���� �������."
    };

    public static IReadOnlyList<ItemDefinition> Items { get; } = new List<ItemDefinition>
    {
        new()
        {
            Id = "weapon.sword",
            Name = "�������� ���",
            Category = ItemCategory.Attack,
            Description = "������, ���������� �� �������� �������. ������� ���������� ��������� ������.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "might", RequiredPoints = 3 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "damage",
                    Description = "������� ���� �� ��������� ����.",
                    BaseValue = 18,
                    ScalingAttributeId = "might",
                    ScalingPerPoint = 2,
                    Unit = "��. �����"
                }
            },
            ConsumedOnUse = false
        },
        new()
        {
            Id = "weapon.staff",
            Name = "������� �����",
            Category = ItemCategory.Attack,
            Description = "����� ��� ������������ �������, ����������� ��������� ����������������� ���� ������������ �������.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "might", RequiredPoints = 2 },
                new() { AttributeId = "arcana", RequiredPoints = 4 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "damage",
                    Description = "����������� ��� �������� �������.",
                    BaseValue = 16,
                    ScalingAttributeId = "arcana",
                    ScalingPerPoint = 3,
                    Unit = "��. �����"
                },
                new()
                {
                    StatId = "overheat",
                    Description = "���� ��������� ������, ��������� ������� ������.",
                    BaseValue = 10,
                    ScalingAttributeId = "arcana",
                    ScalingPerPoint = -1.5,
                    Unit = "% �����������"
                }
            },
            ConsumedOnUse = false
        },
        new()
        {
            Id = "armor.shield",
            Name = "��� �� ������������ �������",
            Category = ItemCategory.Defense,
            Description = "���, ���������� �� �������� ������ ������, ��������� � �������������� ��������.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "might", RequiredPoints = 2 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "mitigation",
                    Description = "������� ������������ ��������� �����.",
                    BaseValue = 40,
                    ScalingAttributeId = "might",
                    ScalingPerPoint = 4,
                    Unit = "%"
                },
                new()
                {
                    StatId = "max-block",
                    Description = "������������ ����� �����, ������� ����� �������� �� ���� ���.",
                    BaseValue = 32,
                    ScalingAttributeId = "vitality",
                    ScalingPerPoint = 3,
                    Unit = "��. �����"
                }
            },
            ConsumedOnUse = false
        },
        new()
        {
            Id = "consumable.bandage",
            Name = "������� ����",
            Category = ItemCategory.Healing,
            Description = "����������� ������, ��������� � �����. ������ ��������������� ��������, �� ����������� ��� ����������.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "aid", RequiredPoints = 2 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "healing",
                    Description = "���������� �������������� ��������.",
                    BaseValue = 22,
                    ScalingAttributeId = "aid",
                    ScalingPerPoint = 3,
                    Unit = "��. ��������"
                }
            },
            ConsumedOnUse = true
        }
    };

    public static BossProfile BossProfile { get; } = new()
    {
        Name = "������������ �����",
        Title = "����� ���������� ������",
        Backstory = "����� ��� ������ ������� ��������� ��� �������� �������-�����, �� ������� �������� ����� ��������� ����������� �������.",
        CombatStyle = "�������� ����������� ����� � ��������� ������� �������, �������� ���� �� ���� ����� ������.",
        MaxHealth = 120,
        StartingRage = 10,
        SignatureEquipment = new List<string>
        {
            "�������� ���� ��������",
            "������� �� ����������� ��������",
            "������ �������������� �����"
        },
        RagePhases = new List<BossRagePhase>
        {
            new()
            {
                RageThreshold = 0,
                Description = "������� ���������. ����� ����������� ���� � ��������� �� ������.",
                AttackProfile = "���������� ��������� ����� �������� � �������� ����."
            },
            new()
            {
                RageThreshold = 40,
                Description = "������ �����, ����� ����������� ������� �� ����.",
                AttackProfile = "��������� ���� ������, ������ ����� �������������� ������."
            },
            new()
            {
                RageThreshold = 75,
                Description = "����� �����. ����� �������� ����� ������������ ����������.",
                AttackProfile = "��������� ����������� ����� � �������������� ��������, ��������� ����������� ������."
            },
            new()
            {
                RageThreshold = 90,
                Description = "�������������� �����������, ����� ������ ������� ��-��� ��������.",
                AttackProfile = "���������� ��������� '������ ������' � ����, ������� ����� �������� ���� ������� �����."
            }
        }
    };
}