import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Password, PasswordDocument } from './password.schema';
import { CreatePasswordDto } from './dto/create-password.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';

@Injectable()
export class PasswordsService {
  constructor(
    @InjectModel(Password.name)
    private readonly model: Model<PasswordDocument>,
  ) {}

  create(userId: string, dto: CreatePasswordDto) {
    return this.model.create({ ...dto, userId });
  }

  findAll(userId: string) {
    return this.model.find({ userId }).sort({ platform: 1, label: 1 }).exec();
  }

  async findOne(userId: string, id: string) {
    const doc = await this.model.findOne({ _id: id, userId }).exec();
    if (!doc) throw new NotFoundException('Password entry not found');
    return doc;
  }

  async update(userId: string, id: string, dto: UpdatePasswordDto) {
    const updated = await this.model
      .findOneAndUpdate({ _id: id, userId }, dto, { new: true })
      .exec();
    if (!updated) throw new NotFoundException('Password entry not found');
    return updated;
  }

  async remove(userId: string, id: string) {
    const result = await this.model.deleteOne({ _id: id, userId }).exec();
    if (result.deletedCount === 0) {
      throw new NotFoundException('Password entry not found');
    }
    return { deleted: true };
  }
}
