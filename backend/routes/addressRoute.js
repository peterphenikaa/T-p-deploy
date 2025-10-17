const express = require('express');
const router = express.Router();
const Address = require('../models/address');

// GET all addresses for a user
router.get('/:userId', async (req, res) => {
  try {
    const addresses = await Address.find({ userId: req.params.userId }).sort({ isDefault: -1, createdAt: -1 });
    res.json(addresses);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// GET default address for a user
router.get('/:userId/default', async (req, res) => {
  try {
    const address = await Address.findOne({ userId: req.params.userId, isDefault: true });
    if (!address) {
      // If no default address, return the first address
      const firstAddress = await Address.findOne({ userId: req.params.userId }).sort({ createdAt: -1 });
      return res.json(firstAddress);
    }
    res.json(address);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// POST create new address
router.post('/', async (req, res) => {
  try {
    const { userId, fullName, phoneNumber, street, ward, district, city, note, isDefault } = req.body;

    // If this is set as default, unset other default addresses
    if (isDefault) {
      await Address.updateMany({ userId }, { isDefault: false });
    }

    const address = new Address({
      userId,
      fullName,
      phoneNumber,
      street,
      ward,
      district,
      city,
      note,
      isDefault: isDefault || false
    });

    const savedAddress = await address.save();
    res.status(201).json(savedAddress);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

// PUT update address
router.put('/:id', async (req, res) => {
  try {
    const { fullName, phoneNumber, street, ward, district, city, note, isDefault } = req.body;

    // If this is set as default, unset other default addresses
    if (isDefault) {
      const address = await Address.findById(req.params.id);
      if (address) {
        await Address.updateMany({ userId: address.userId }, { isDefault: false });
      }
    }

    const updatedAddress = await Address.findByIdAndUpdate(
      req.params.id,
      { fullName, phoneNumber, street, ward, district, city, note, isDefault },
      { new: true, runValidators: true }
    );

    if (!updatedAddress) {
      return res.status(404).json({ message: 'Address not found' });
    }

    res.json(updatedAddress);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

// DELETE address
router.delete('/:id', async (req, res) => {
  try {
    const deletedAddress = await Address.findByIdAndDelete(req.params.id);
    if (!deletedAddress) {
      return res.status(404).json({ message: 'Address not found' });
    }
    res.json({ message: 'Address deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// PUT set default address
router.put('/:id/set-default', async (req, res) => {
  try {
    const address = await Address.findById(req.params.id);
    if (!address) {
      return res.status(404).json({ message: 'Address not found' });
    }

    // Unset other default addresses for this user
    await Address.updateMany({ userId: address.userId }, { isDefault: false });

    // Set this address as default
    address.isDefault = true;
    await address.save();

    res.json(address);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
