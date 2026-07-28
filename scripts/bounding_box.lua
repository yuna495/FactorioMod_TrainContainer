local bounding_box = {}

function bounding_box.width(box)
	return box.right_bottom.x - box.left_top.x
end

function bounding_box.height(box)
	return box.right_bottom.y - box.left_top.y
end

function bounding_box.center(box)
	return {
		x = (box.left_top.x + box.right_bottom.x) / 2,
		y = (box.left_top.y + box.right_bottom.y) / 2
	}
end

return bounding_box
