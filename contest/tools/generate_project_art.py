import random
import math
import os

def create_generative_art(filename="figures/project_art.svg"):
    """
    Generates a futuristic "Neural Learning Network" art piece in SVG format.
    """
    width = 800
    height = 600
    
    # Colors
    bg_color = "#0f172a"  # Dark Slate
    node_colors = ["#00f3ff", "#bd00ff", "#ff00aa", "#ffe600"] # Neon Cyan, Purple, Pink, Yellow
    line_color = "#38bdf8" # Light Blue
    
    svg_content = [
        f'<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg" style="background-color:{bg_color}">'
    ]
    
    # 1. Background Grid (Subtle)
    for i in range(0, width, 40):
        svg_content.append(f'<line x1="{i}" y1="0" x2="{i}" y2="{height}" stroke="#1e293b" stroke-width="1" />')
    for i in range(0, height, 40):
        svg_content.append(f'<line x1="0" y1="{i}" x2="{width}" y2="{i}" stroke="#1e293b" stroke-width="1" />')

    # 2. Generate Nodes
    nodes = []
    num_nodes = 50
    margin = 50
    
    # Central Goal Node
    center_x, center_y = width // 2, height // 2
    nodes.append({"x": center_x, "y": center_y, "r": 20, "color": "#ffffff", "glow": True})

    for _ in range(num_nodes):
        x = random.randint(margin, width - margin)
        y = random.randint(margin, height - margin)
        # Distribute somewhat away from center to look nice
        distance_to_center = math.sqrt((x - center_x)**2 + (y - center_y)**2)
        
        radius = random.randint(3, 8)
        color = random.choice(node_colors)
        nodes.append({"x": x, "y": y, "r": radius, "color": color, "glow": False})

    # 3. Draw Connections (Neural Pathways)
    # Connect closer nodes
    for i, node_a in enumerate(nodes):
        for j, node_b in enumerate(nodes):
            if i >= j: continue
            
            dist = math.sqrt((node_a["x"] - node_b["x"])**2 + (node_a["y"] - node_b["y"])**2)
            
            if dist < 120:
                opacity = 1 - (dist / 120)
                width_line = 0.5 + opacity
                
                # If connected to center, make it stronger
                if i == 0 or j == 0:
                    width_line *= 2
                    opacity = min(1.0, opacity + 0.3)
                    
                svg_content.append(
                    f'<line x1="{node_a["x"]}" y1="{node_a["y"]}" x2="{node_b["x"]}" y2="{node_b["y"]}" '
                    f'stroke="{line_color}" stroke-width="{width_line}" stroke-opacity="{opacity}" />'
                )

    # 4. Draw Nodes
    for node in nodes:
        # Glow effect (simple multiple circles)
        if node.get("glow"):
            for r in range(node["r"] + 10, node["r"], -2):
                svg_content.append(
                    f'<circle cx="{node["x"]}" cy="{node["y"]}" r="{r}" fill="{node["color"]}" opacity="0.1" />'
                )
        
        svg_content.append(
            f'<circle cx="{node["x"]}" cy="{node["y"]}" r="{node["r"]}" fill="{node["color"]}" />'
        )
        # Inner white dot for "tech" feel
        svg_content.append(
            f'<circle cx="{node["x"]}" cy="{node["y"]}" r="{node["r"]/2}" fill="#ffffff" opacity="0.5" />'
        )

    # 5. Add Text (Project Name)
    svg_content.append(
        f'<text x="{width - 20}" y="{height - 20}" font-family="Arial, sans-serif" font-size="14" '
        f'fill="#64748b" text-anchor="end">Learning Optimizer AI</text>'
    )

    svg_content.append('</svg>')
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    with open(filename, "w") as f:
        f.write("\n".join(svg_content))
    
    print(f"Generative art saved to {os.path.abspath(filename)}")

if __name__ == "__main__":
    create_generative_art()
